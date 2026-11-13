-- Table privileges for the Data API, and a guard on the thing they rest on.
--
-- Neon's Data API has no permission layer of its own: it authorizes entirely
-- through Postgres GRANTs and row level security. Supabase worked the same
-- way, which is why the policies ported unchanged -- but on Supabase the
-- grants came with the platform, so this file had no counterpart there and is
-- new. Getting it wrong is how a catalogue table ends up world-writable.
--
-- The shape is deliberately broad-grant, narrow-policy, exactly as before:
-- every role may attempt any statement, and RLS decides which rows it sees or
-- touches. That is safe only because RLS is enabled on every table and
-- Postgres denies by default -- a table with RLS on and no policy for a
-- command rejects that command outright. So the catalogue tables, which carry
-- only a SELECT policy, are read-only to clients even though the grant below
-- says insert, update, delete.
--
-- Written by hand, not generated: it is Neon-specific and has no Supabase
-- original to be ported from.

grant usage on schema public to anonymous, authenticated;

-- Signed out: may read. Which rows, the policies decide -- an owner-only
-- table compares user_id against auth.uid(), which is null here, so it
-- returns nothing rather than erroring.
grant select on all tables in schema public to anonymous;

-- Signed in: may attempt anything; the policies decide what lands.
grant select, insert, update, delete on all tables in schema public to authenticated;

grant usage, select on all sequences in schema public to anonymous, authenticated;

-- A table added later must not arrive unreachable (or, worse, reachable
-- without anyone noticing it was never granted deliberately).
alter default privileges in schema public
  grant select on tables to anonymous;
alter default privileges in schema public
  grant select, insert, update, delete on tables to authenticated;

-- The guard. Everything above is safe only while RLS is on everywhere; a
-- single table with it off is fully exposed through the Data API, to
-- anonymous callers, with no error anywhere to show for it. Fail the
-- migration rather than grant into that.
do $$
declare
  unprotected text;
begin
  select string_agg(c.relname, ', ' order by c.relname)
    into unprotected
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind = 'r'
    and not c.relrowsecurity;

  if unprotected is not null then
    raise exception
      'Row level security is off on: %. The Data API authorizes through '
      'GRANT plus RLS only, so these tables would be readable, and writable '
      'by any signed-in user, through the REST API. Enable RLS and add '
      'policies before granting.', unprotected;
  end if;
end;
$$;
