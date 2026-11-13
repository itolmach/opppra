-- The one piece of the Supabase schema that could not be ported.
--
-- On Supabase a trigger on auth.users created a profile row and the two
-- default lists the moment an account was made. Neon's user table
-- (neon_auth."user") is managed by the platform: opera_owner has SELECT and
-- REFERENCES on it -- which is why the foreign keys port fine -- but not
-- TRIGGER, so `create trigger ... on neon_auth."user"` is refused outright.
--
-- Instead the clients call this once after sign-in. It is idempotent, so
-- calling it on every sign-in is correct and cheap, and both the web app and
-- the iOS app call the same function rather than reimplementing the rule
-- twice and drifting.
--
-- Hand-written: Neon-specific, with no Supabase original to port from.

create or replace function public.ensure_user_bootstrap()
returns void
language plpgsql
security definer
set search_path = public, neon_auth
as $$
declare
  caller uuid := auth.uid();
begin
  -- SECURITY DEFINER runs this as the table owner, bypassing row level
  -- security, so what it may touch has to be pinned here instead. It takes no
  -- arguments and only ever acts on auth.uid(): there is deliberately no way
  -- for a caller to name a different user and bootstrap -- or overwrite --
  -- somebody else's rows.
  if caller is null then
    raise exception 'ensure_user_bootstrap() requires a signed-in caller';
  end if;

  insert into public.profiles (id, email, display_name)
  select u.id, u.email, nullif(u.name, '')
  from neon_auth."user" u
  where u.id = caller
  on conflict (id) do nothing;

  -- Matches the partial unique index on (user_id, type) where is_default,
  -- so a second call changes nothing rather than raising.
  insert into public.user_lists (user_id, name, type, is_default)
  values
    (caller, 'Wanna Experience', 'wants_to_experience', true),
    (caller, 'Have Experienced', 'has_experienced', true)
  on conflict (user_id, type) where is_default do nothing;
end;
$$;

-- Signed-in callers only. PUBLIC gets EXECUTE on new functions by default,
-- which on a SECURITY DEFINER function would hand anonymous callers the
-- owner's privileges -- the function would reject them at auth.uid(), but
-- revoking is the part that should not depend on the body being right.
revoke execute on function public.ensure_user_bootstrap() from public;
revoke execute on function public.ensure_user_bootstrap() from anonymous;
grant execute on function public.ensure_user_bootstrap() to authenticated;
