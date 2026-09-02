-- Opera app schema
-- Run this in the Supabase SQL editor (or via `supabase db push`) on a fresh project.
-- Safe to re-run: every statement is guarded with IF NOT EXISTS / OR REPLACE.

create extension if not exists "pgcrypto";

-- =========================================================================
-- Profiles (1:1 with auth.users)
-- =========================================================================

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  display_name text,
  profile_image_url text,
  bio text,
  is_profile_public boolean not null default false,
  show_stats boolean not null default true,
  show_lists boolean not null default false,
  favorite_composers text[] not null default '{}',
  favorite_choreographers text[] not null default '{}',
  favorite_eras text[] not null default '{}',
  favorite_houses text[] not null default '{}',
  primary_house text,
  has_completed_onboarding boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own_or_public" on public.profiles;
create policy "profiles_select_own_or_public" on public.profiles
  for select using (auth.uid() = id or is_profile_public);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);

-- Auto-create a profile row + the two default lists whenever a new auth
-- user is created. This runs before public.user_lists exists lexically in
-- this file, which is fine -- it's a function body, evaluated at call time
-- (after the whole migration has been applied), not at create-function time.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data ->> 'display_name', null))
  on conflict (id) do nothing;

  insert into public.user_lists (user_id, name, type, is_default)
  values
    (new.id, 'Wanna Experience', 'wants_to_experience', true),
    (new.id, 'Have Experienced', 'has_experienced', true)
  on conflict (user_id, type) where is_default do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =========================================================================
-- Catalog: venues, productions, cast, performances
-- (Opera works themselves are sourced live from the OpenOpus API and are
--  not duplicated here; these tables hold data OpenOpus does not provide.)
-- =========================================================================

create table if not exists public.venues (
  id text primary key,
  name text not null,
  city text not null,
  country text not null,
  address text,
  latitude double precision,
  longitude double precision,
  image_url text,
  website text,
  capacity integer,
  created_at timestamptz not null default now()
);

alter table public.venues enable row level security;
drop policy if exists "venues_select_all" on public.venues;
create policy "venues_select_all" on public.venues for select using (true);

create table if not exists public.productions (
  id text primary key,
  opera_id text not null,
  opera_title text not null,
  company text not null,
  company_id text,
  director text,
  conductor text,
  choreographer text,
  production_year integer,
  designer text,
  venue_id text references public.venues (id),
  description text,
  image_url text,
  image_gallery text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists productions_opera_id_idx on public.productions (opera_id);

alter table public.productions enable row level security;
drop policy if exists "productions_select_all" on public.productions;
create policy "productions_select_all" on public.productions for select using (true);

create table if not exists public.cast_members (
  id text primary key,
  production_id text not null references public.productions (id) on delete cascade,
  name text not null,
  role text not null,
  artist_id text,
  image_url text
);

create index if not exists cast_members_production_id_idx on public.cast_members (production_id);

alter table public.cast_members enable row level security;
drop policy if exists "cast_members_select_all" on public.cast_members;
create policy "cast_members_select_all" on public.cast_members for select using (true);

create table if not exists public.performances (
  id text primary key,
  production_id text not null references public.productions (id) on delete cascade,
  date timestamptz not null,
  time text not null,
  ticket_url text,
  ticket_price_range text,
  is_sold_out boolean not null default false,
  notes text
);

create index if not exists performances_production_id_idx on public.performances (production_id);
create index if not exists performances_date_idx on public.performances (date);

alter table public.performances enable row level security;
drop policy if exists "performances_select_all" on public.performances;
create policy "performances_select_all" on public.performances for select using (true);

-- =========================================================================
-- User lists ("Wanna Experience", "Have Experienced", custom lists)
-- =========================================================================

create table if not exists public.user_lists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  type text not null check (type in ('wants_to_experience', 'has_experienced', 'custom')),
  is_default boolean not null default false,
  color text,
  icon_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists user_lists_user_id_idx on public.user_lists (user_id);
create unique index if not exists user_lists_default_unique_idx
  on public.user_lists (user_id, type) where is_default;

alter table public.user_lists enable row level security;
drop policy if exists "user_lists_all_own" on public.user_lists;
create policy "user_lists_all_own" on public.user_lists
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table if not exists public.list_items (
  id uuid primary key default gen_random_uuid(),
  list_id uuid not null references public.user_lists (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  opera_id text not null,
  opera_title text not null,
  composer text not null,
  image_url text,
  notes text,
  tags text[] not null default '{}',
  priority integer,
  experienced_date timestamptz,
  rating double precision check (rating is null or (rating >= 0 and rating <= 5)),
  production_id text,
  added_at timestamptz not null default now()
);

create index if not exists list_items_list_id_idx on public.list_items (list_id);
create index if not exists list_items_user_id_idx on public.list_items (user_id);

alter table public.list_items enable row level security;
drop policy if exists "list_items_all_own" on public.list_items;
create policy "list_items_all_own" on public.list_items
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- =========================================================================
-- Attendance logs
-- =========================================================================

create table if not exists public.attendance_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  opera_id text not null,
  opera_title text not null,
  composer text not null,
  production_id text references public.productions (id),
  venue_id text references public.venues (id),
  venue_name text not null,
  city text not null,
  country text not null,
  attendance_date timestamptz not null,
  performance_time text,
  overall_rating double precision check (overall_rating is null or (overall_rating >= 0 and overall_rating <= 5)),
  music_rating double precision check (music_rating is null or (music_rating >= 0 and music_rating <= 5)),
  performance_rating double precision check (performance_rating is null or (performance_rating >= 0 and performance_rating <= 5)),
  production_rating double precision check (production_rating is null or (production_rating >= 0 and production_rating <= 5)),
  notes text,
  tags text[] not null default '{}',
  photos text[] not null default '{}',
  -- Populated by the opera-companion web app (cast list + a comment thread
  -- on the log entry); the iOS app doesn't read/write these but tolerates
  -- their presence -- Swift's JSONDecoder ignores keys a struct doesn't
  -- declare, so this doesn't require any iOS-side change.
  cast jsonb not null default '[]'::jsonb,
  comments jsonb not null default '[]'::jsonb,
  ticket_image_url text,
  ticket_scanned_text text,
  ticket_extracted_date timestamptz,
  ticket_extracted_venue text,
  ticket_extracted_seat_info text,
  ticket_extracted_price text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists attendance_logs_user_id_idx on public.attendance_logs (user_id);
create index if not exists attendance_logs_attendance_date_idx on public.attendance_logs (attendance_date);

alter table public.attendance_logs enable row level security;
drop policy if exists "attendance_logs_all_own" on public.attendance_logs;
create policy "attendance_logs_all_own" on public.attendance_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- =========================================================================
-- Recommendation feedback (thumbs up/down on a suggestion, so the same
-- suggestion isn't served again). Recommendations themselves are computed
-- on-demand from the user's taste profile + catalog, not stored.
-- =========================================================================

create table if not exists public.recommendation_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  reference_id text not null,
  reference_type text not null,
  liked boolean not null,
  created_at timestamptz not null default now(),
  unique (user_id, reference_id, reference_type)
);

alter table public.recommendation_feedback enable row level security;
drop policy if exists "recommendation_feedback_all_own" on public.recommendation_feedback;
create policy "recommendation_feedback_all_own" on public.recommendation_feedback
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- =========================================================================
-- Keep profile stats (total_experienced / total_wishlist) in sync
-- =========================================================================

create or replace function public.recompute_profile_stats(p_user_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  update public.profiles
  set updated_at = now()
  where id = p_user_id;
end;
$$;

-- total_experienced / total_wishlist are derived at read time via the
-- profile_stats view below rather than duplicated on profiles, so they can
-- never drift out of sync with list_items.
create or replace view public.profile_stats as
select
  ul.user_id,
  count(*) filter (where ul.type = 'has_experienced') as total_experienced,
  count(*) filter (where ul.type = 'wants_to_experience') as total_wishlist
from public.user_lists ul
join public.list_items li on li.list_id = ul.id
group by ul.user_id;

alter view public.profile_stats set (security_invoker = on);
