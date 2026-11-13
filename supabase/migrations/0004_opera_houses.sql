-- Opera houses, their playbills, and the houses a person wants to visit.
--
-- This is the second half of "our own database": 0003 holds the works, this
-- holds where and when they are performed. Between them they answer the two
-- questions an opera-goer actually has -- what is this opera, and where can I
-- see it -- which is what makes the data worth coming to us for.
--
-- Applied to the project on 2026-09-20. Recorded here so the schema can be
-- rebuilt from the repository rather than from the dashboard.

-- A house is public reference data. Rows are added by us, not by clients.
create table if not exists public.opera_houses (
  id uuid primary key default gen_random_uuid(),
  -- Stable, human-readable, and what the web app puts in the URL
  -- (/afisha/theatre?slug=mariinsky). Renaming a house must not break a link,
  -- so this is the key clients use rather than the uuid.
  slug text not null unique,
  -- The name the house calls itself, in its own language. name_en is for
  -- interfaces that are not Russian; it is not a fallback for `name`.
  name text not null,
  name_en text,
  city text not null,
  country text not null,
  website text,
  -- Where its schedule lives, when that is not the site root. Shown to the
  -- visitor when we have no entries for the house, so the page is still
  -- useful rather than apologetic.
  playbill_url text,
  image_url text,
  -- What time a performance starts is a fact about the house, not about
  -- whoever is reading the bill. Formatted in the viewer's zone instead, the
  -- Mariinsky's 19:00 performances read 16:00 from anywhere west of Moscow,
  -- and a late one lands on the wrong day and under the wrong month heading.
  timezone text not null default 'Europe/Moscow',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- For databases created before the column existed. It was added to the
-- project directly and lived only there for a while, which is how the Neon
-- port came up one column short: the repo, not the running database, has to
-- be the thing the schema is rebuilt from.
alter table public.opera_houses
  add column if not exists timezone text not null default 'Europe/Moscow';

update public.opera_houses set timezone = 'Asia/Almaty'
  where slug = 'astana-opera' and timezone = 'Europe/Moscow';
update public.opera_houses set timezone = 'Asia/Yekaterinburg'
  where slug = 'perm-opera' and timezone = 'Europe/Moscow';

create table if not exists public.playbill_entries (
  id uuid primary key default gen_random_uuid(),
  house_id uuid not null references public.opera_houses(id) on delete cascade,
  -- The MusicBrainz work id, the same identifier attendance_logs.opera_id and
  -- list_items.opera_id carry. Deliberately not a foreign key to
  -- opera_works: a house can announce a premiere of something no catalogue
  -- holds yet, and that performance still belongs on the bill.
  opera_id uuid,
  -- What the house calls it, kept whether or not it matched. This is the
  -- evidence for the match, and the only thing to display when there is none.
  work_title text not null,
  starts_at timestamptz not null,
  url text,
  -- Which house listing this came from, so a source that changes its markup
  -- can have its rows re-read without touching anyone else's.
  source text not null default 'manual',
  fetched_at timestamptz not null default now(),
  -- What makes a performance the same performance on a re-read. The house's
  -- own event id would be better, but not every house exposes one, and these
  -- three together identify an evening.
  unique (house_id, work_title, starts_at)
);

create index if not exists playbill_entries_opera_id_idx
  on public.playbill_entries (opera_id);
-- The query the app makes: one house, in date order.
create index if not exists playbill_entries_house_starts_idx
  on public.playbill_entries (house_id, starts_at);

create table if not exists public.user_saved_houses (
  user_id uuid not null references auth.users(id) on delete cascade,
  house_id uuid not null references public.opera_houses(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, house_id)
);

alter table public.opera_houses enable row level security;
alter table public.playbill_entries enable row level security;
alter table public.user_saved_houses enable row level security;

-- Houses and playbills are readable by anyone, signed in or not: they are
-- public facts about public performances, and the app shows them before
-- asking for an account. There is deliberately no client write path -- rows
-- arrive through scripts/fetch-playbill.mjs with the service role, so a
-- compromised anon key cannot put a fake performance on a real house's bill.
drop policy if exists opera_houses_public_read on public.opera_houses;
create policy opera_houses_public_read on public.opera_houses
  for select using (true);

drop policy if exists playbill_public_read on public.playbill_entries;
create policy playbill_public_read on public.playbill_entries
  for select using (true);

-- Which houses somebody wants to visit is theirs alone, on the same terms as
-- their wishlist. Both using and with check, so the policy covers reads and
-- writes: without the check, a client could insert a row owned by someone
-- else and then never be able to see it.
drop policy if exists user_saved_houses_own on public.user_saved_houses;
create policy user_saved_houses_own on public.user_saved_houses
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
