-- =========================================================================
-- Our own opera catalogue.
--
-- Until now the catalogue was a JSON file rebuilt from MusicBrainz on every
-- refresh. That is fine for reading and useless for owning: nothing we add
-- survives a rebuild, there is nowhere to record where a fact came from, and
-- there is no way for anyone to contribute.
--
-- These tables are the catalogue itself. MusicBrainz and Wikidata become
-- sources that seed and enrich it, rather than the thing we are.
--
-- Licensing, which matters because this is meant to become a product:
--   MusicBrainz CORE data (works, artists, names, aliases, MBIDs) is CC0 --
--   public domain, commercial use unrestricted. Its SUPPLEMENTARY data
--   (tags, ratings, annotations) is CC-BY-NC-SA and is deliberately not used.
--   Wikidata is CC0. Wikipedia prose is CC-BY-SA 4.0, whose share-alike term
--   would reach into anything we derive from it, so any description taken
--   from there is recorded as such and kept separable.
-- That is what `licence` on opera_sources is for: so the provenance of every
-- fact is auditable rather than remembered.
-- =========================================================================

create extension if not exists "pgcrypto";

-- -------------------------------------------------------------------------
-- Composers
-- -------------------------------------------------------------------------
create table if not exists public.opera_composers (
  id uuid primary key default gen_random_uuid(),
  -- Display name in its own script: "Модест Петрович Мусоргский" stays as it
  -- is, because that is what the work is credited to.
  name text not null,
  -- Latin form for sorting and for searching from a Latin keyboard.
  sort_name text,
  born_year integer,
  died_year integer,
  portrait_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists opera_composers_name_idx on public.opera_composers (lower(name));

-- -------------------------------------------------------------------------
-- Works
-- -------------------------------------------------------------------------
create table if not exists public.opera_works (
  -- Our own id, which is the point of the exercise. External ids live in
  -- opera_sources; they are references, not identity. A work that exists
  -- nowhere else still gets a real id here.
  id uuid primary key default gen_random_uuid(),
  composer_id uuid not null references public.opera_composers (id) on delete restrict,
  -- The title in the work's own language, as it would appear on a poster.
  title text not null,
  -- Folded form used for duplicate detection and search. Maintained by the
  -- application rather than a trigger so the rule lives in one place.
  match_key text not null,
  -- ISO 639-3, e.g. "ita", "rus".
  language text,
  premiere_year integer,
  premiere_date date,
  premiere_venue text,
  premiere_city text,
  premiere_country text,
  -- CC-BY-SA text (Wikipedia) must stay attributable and separable from
  -- anything we write ourselves, hence both the text and its source.
  description text,
  description_source text,
  image_url text,
  -- published: visible to everyone. pending: submitted, awaiting review.
  -- rejected: reviewed and declined. merged: a duplicate, superseded.
  status text not null default 'pending'
    check (status in ('published', 'pending', 'rejected', 'merged')),
  merged_into uuid references public.opera_works (id) on delete set null,
  submitted_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- One composer cannot have the same work twice. This is the duplicate problem
-- that kept coming back, enforced by the database instead of by a script that
-- someone might forget to carry across a rewrite.
create unique index if not exists opera_works_composer_match_key_uniq
  on public.opera_works (composer_id, match_key)
  where status <> 'merged';

create index if not exists opera_works_status_idx on public.opera_works (status);
create index if not exists opera_works_premiere_year_idx on public.opera_works (premiere_year);

-- -------------------------------------------------------------------------
-- Titles in other languages
-- -------------------------------------------------------------------------
create table if not exists public.opera_titles (
  id uuid primary key default gen_random_uuid(),
  work_id uuid not null references public.opera_works (id) on delete cascade,
  -- BCP-47-ish short code: "ru", "it", "de", "fr", "en".
  language text not null,
  title text not null,
  created_at timestamptz not null default now(),
  unique (work_id, language, title)
);

create index if not exists opera_titles_work_id_idx on public.opera_titles (work_id);

-- -------------------------------------------------------------------------
-- Provenance
-- -------------------------------------------------------------------------
create table if not exists public.opera_sources (
  id uuid primary key default gen_random_uuid(),
  work_id uuid not null references public.opera_works (id) on delete cascade,
  -- musicbrainz | wikidata | wikipedia | user | opera_house
  source text not null,
  external_id text,
  url text,
  -- Recorded per row, not assumed: CC0 and CC-BY-SA carry very different
  -- obligations, and which applies depends on where the row came from.
  licence text,
  fetched_at timestamptz not null default now(),
  unique (work_id, source, external_id)
);

create index if not exists opera_sources_lookup_idx on public.opera_sources (source, external_id);

-- -------------------------------------------------------------------------
-- Contributions
-- -------------------------------------------------------------------------
create table if not exists public.opera_contributions (
  id uuid primary key default gen_random_uuid(),
  -- Null when proposing a work that does not exist yet.
  work_id uuid references public.opera_works (id) on delete cascade,
  submitted_by uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('new_work', 'correction')),
  payload jsonb not null,
  note text,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'rejected')),
  reviewed_by uuid references auth.users (id) on delete set null,
  reviewed_at timestamptz,
  review_note text,
  created_at timestamptz not null default now()
);

create index if not exists opera_contributions_status_idx on public.opera_contributions (status);
create index if not exists opera_contributions_submitter_idx on public.opera_contributions (submitted_by);

-- -------------------------------------------------------------------------
-- Row level security
--
-- The catalogue is meant to be read by anyone, including while signed out --
-- that is the product. Writing is another matter: nothing reaches the public
-- catalogue without review, so the tables are readable but not writable, and
-- proposals go through opera_contributions.
-- -------------------------------------------------------------------------
alter table public.opera_composers enable row level security;
alter table public.opera_works enable row level security;
alter table public.opera_titles enable row level security;
alter table public.opera_sources enable row level security;
alter table public.opera_contributions enable row level security;

drop policy if exists "opera_composers_public_read" on public.opera_composers;
create policy "opera_composers_public_read" on public.opera_composers
  for select using (true);

-- Only published works are public. Pending and rejected ones are visible to
-- whoever submitted them, so a contributor can see what happened to theirs.
drop policy if exists "opera_works_public_read" on public.opera_works;
create policy "opera_works_public_read" on public.opera_works
  for select using (status = 'published' or submitted_by = auth.uid());

drop policy if exists "opera_titles_public_read" on public.opera_titles;
create policy "opera_titles_public_read" on public.opera_titles
  for select using (
    exists (
      select 1 from public.opera_works w
      where w.id = work_id and (w.status = 'published' or w.submitted_by = auth.uid())
    )
  );

drop policy if exists "opera_sources_public_read" on public.opera_sources;
create policy "opera_sources_public_read" on public.opera_sources
  for select using (
    exists (
      select 1 from public.opera_works w
      where w.id = work_id and (w.status = 'published' or w.submitted_by = auth.uid())
    )
  );

-- A signed-in person may propose anything and read their own proposals.
-- Nobody may edit a proposal after review, and nobody may review their own:
-- both of those are enforced here rather than trusted to the client.
drop policy if exists "opera_contributions_insert_own" on public.opera_contributions;
create policy "opera_contributions_insert_own" on public.opera_contributions
  for insert with check (submitted_by = auth.uid());

drop policy if exists "opera_contributions_select_own" on public.opera_contributions;
create policy "opera_contributions_select_own" on public.opera_contributions
  for select using (submitted_by = auth.uid());

drop policy if exists "opera_contributions_update_own_pending" on public.opera_contributions;
create policy "opera_contributions_update_own_pending" on public.opera_contributions
  for update using (submitted_by = auth.uid() and status = 'pending')
  with check (submitted_by = auth.uid() and status = 'pending');

-- Seeding and moderation run with the service role, which bypasses RLS. There
-- is deliberately no client-side write path into the catalogue tables.
