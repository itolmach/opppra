# Supabase Setup

This is the real backend for both apps in this account:

- **OperaApp** (this repo) — the iOS SwiftUI app.
- **opera-companion** — the Next.js web app. It's a separate repo, but it
  points at the **same Supabase project** as this app: same accounts, same
  wishlist/watched data. See its own README for its side of this setup.

Everything below happens once, for the one shared project.

## 1. Create the Supabase project

1. Go to [supabase.com](https://supabase.com) and create a new project.
2. From Project Settings > API, note down:
   - **Project URL** (`https://<ref>.supabase.co`)
   - **anon public key**
   - (For the delete-account Edge Function only) the **service_role key** —
     never put this in either app, it's server-side only and Supabase
     injects it into Edge Functions automatically.

## 2. Run the migrations

In the SQL Editor (or via the Supabase CLI: `supabase db push` after
`supabase link`), run, in order:

1. `supabase/migrations/0001_init.sql` — tables, RLS policies, the
   new-user trigger (creates a profile + the two default lists
   automatically).
2. `supabase/migrations/0002_storage.sql` — storage buckets
   (`avatars`, `ticket-photos`, `log-photos`) and their access policies.
3. (Optional) `supabase/seed.sql` — a couple of illustrative
   productions/venues so the app isn't empty on first run. Read the
   warning at the top of that file before treating the data as real.

## 3. Configure Auth providers

Authentication > Providers:

- **Email**: on by default. Decide whether to require email confirmation
  (Authentication > Settings) — if you leave it on, `signUp` won't return a
  session until the user clicks the confirmation link, and the app handles
  that case (shows "check your email").
- **Google**: enable it, add your OAuth client ID/secret from Google Cloud
  Console. Needed for opera-companion's sign-in and available to iOS too.
- **Apple**: enable it for Sign in with Apple. On the iOS side you also
  need, in Xcode: Target > Signing & Capabilities > **+ Sign in with
  Apple**.
- Under Authentication > URL Configuration, add opera-companion's
  `/auth/callback` URL (both your deployed URL and
  `http://localhost:3000/auth/callback` for local dev) to the redirect
  allow-list.

## 4. Deploy the delete-account Edge Function

Account deletion needs the service-role key, which never belongs in either
client app, so it runs as an Edge Function instead:

```bash
supabase functions deploy delete-account
```

Nothing else to configure — `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and
`SUPABASE_SERVICE_ROLE_KEY` are already available to every Edge Function
automatically.

## 5. Wire up the iOS app

1. `cp OperaApp/Config/Config.xcconfig.example OperaApp/Config/Config.xcconfig`
   (already done once in this repo with placeholder values — just edit it)
   and fill in your project's URL/anon key.
2. In Xcode: **File > Add Package Dependencies…**, add
   `https://github.com/supabase/supabase-swift`, and add the `Supabase`
   product to the OperaApp target. (This is a manual Xcode step — it can't
   be done by editing the project file blind.)
3. Target > Signing & Capabilities > **+ Sign in with Apple**.
4. Build and run.

## 6. Wire up opera-companion

See that repo's README — in short, copy `.env.local.example` to
`.env.local` with the same project's URL/anon key, and add its
`/auth/callback` redirect URL as described above.

## Keeping the two apps in sync

Both apps read/write the same tables. If a feature needs a schema change,
add a new migration file here (`supabase/migrations/000N_*.sql`) rather
than changing the schema from the other repo — otherwise the two apps'
understanding of the database drifts apart.
