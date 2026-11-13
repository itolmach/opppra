# Neon migrations

The schema, ported to Neon. Applied to project `steep-morning-66838900`
(org "Ivan", `aws-us-east-1`, Postgres 17), database `opera`.

## These are generated, except two

`0001`, `0003` and `0004` are produced by `scripts/port-to-neon.py` from the
Supabase migration of the same number. Edit the Supabase file and re-run the
script; do not edit these by hand. To see what the port changes:

    diff supabase/migrations/0001_init.sql neon/migrations/0001_init.sql

It is less than anyone expects. Neon's Data API validates Managed Better Auth
JWTs and exposes `auth.uid()` returning `uuid` -- the same name and return
type Supabase used -- so **all 21 row level security policies came across
byte for byte**, verified by comparing `pg_policies` on both databases.

`0005` and `0006` are hand-written, because they are Neon-specific and have
no Supabase original.

## Numbering

Matches the Supabase files so the two can be read side by side. `0002` is
absent on purpose: on Supabase it is Storage buckets and policies, which Neon
Object Storage replaces with a different mechanism entirely.

## What did not port, and why

**The signup trigger.** On Supabase a trigger on `auth.users` created a
profile row and the two default lists the moment an account was made.
`neon_auth."user"` is platform-managed: `opera_owner` has SELECT and
REFERENCES on it (which is why the nine foreign keys port fine) but not
TRIGGER. `0006` replaces it with `public.ensure_user_bootstrap()`, an
idempotent RPC the clients call once after sign-in. It takes no arguments and
acts only on `auth.uid()`, so a caller cannot bootstrap or overwrite anyone
else's rows.

**Storage.** `0002_storage.sql` has no equivalent here.

## The part that is easy to get wrong

Neon's Data API has **no permission layer of its own**: it authorizes
entirely through Postgres GRANTs and row level security. On Supabase the
grants came with the platform; here they are `0005`, and they are broad --
every role may attempt any statement, and RLS decides what lands. That is
safe only because RLS is enabled on every table and Postgres denies by
default. `0005` ends with a DO block that fails the migration if any table in
`public` has RLS off, because a single unprotected table would be fully
readable, and writable by any signed-in user, through the REST API, with
nothing anywhere to show for it.

## Applying them

Outbound 5432 is blocked in the build sandbox, so `psql` cannot reach Neon.
They go over HTTPS instead, via `@neondatabase/serverless`, one statement at
a time -- which is what `scripts/split-sql.py` is for: a naive split on `;`
cuts straight through the dollar-quoted function bodies in `0001` and the DO
block in `0005`.

Order matters only in that `0001` must come before the rest, and `0005` last
(its guard should see the finished schema).
