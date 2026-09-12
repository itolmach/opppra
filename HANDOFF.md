# Handoff — finish shipping the web app

**Goal:** get the opera-companion web app live. The iOS app comes after.

Written at the end of a session where the Supabase connector dropped out and
could not be re-enabled mid-conversation. Start a fresh conversation with the
Supabase connector enabled and this file is everything needed to finish.

---

## Supabase projects (org `rajlbkpyxdiiddzezcbu`, **free plan**)

| Project | ID | State | Role |
| --- | --- | --- | --- |
| Opera and Ballet Tracker | `ypblzqaltozesxxgcyha` | restored, **empty** | **production** |
| opera-companion | `inxcorxhhhoqmjkrjqjj` | paused | future staging |
| tolmachev-family-budget | `qwazgxmlichidhcjkkhi` | active | unrelated |

Production URL: `https://ypblzqaltozesxxgcyha.supabase.co`

> **Free plan allows 2 active projects.** The budget project holds one slot and
> production the other, so staging cannot be restored without pausing something
> or upgrading. Preview branches therefore can't work yet — that's expected and
> handled: they build without a database and say so at runtime.

Verified with `list_tables` that production is empty, so the migrations are
safe to apply to it as-is.

---

## What's already done

- Both web branches merged into `opera-companion` `main` and pushed.
- The `main` deploy workflow **ran and succeeded** — `gh-pages` holds a real
  build. It was built without Supabase credentials, so the app currently shows
  the "this build has no Supabase connection" message by design.
- GitHub Actions already has write permission (an earlier run proved it).
- The deploy workflow selects credentials by branch: `main` → production,
  everything else → staging.
- Fixed a bug that would have broken the very first migration run: a column
  named `cast`, which is a reserved word in Postgres.

## What's left

### 1. Apply the schema to production (`ypblzqaltozesxxgcyha`)

Use `apply_migration` for each, in order:

- `supabase/migrations/0001_init.sql` — 9 tables, RLS on every one, the
  new-user trigger that creates a profile plus the two default lists.
- `supabase/migrations/0002_storage.sql` — three storage buckets and their
  owner-only policies.

Optional, staging only later: `supabase/seed.sql`.

Then run `get_advisors` (type `security`) and confirm nothing reports a table
without RLS before any real data lands.

### 2. Deploy the edge function

`supabase/functions/delete-account/index.ts` — account deletion needs the
service-role key, so it can't run from either client app.

### 3. Wire the credentials into the web app

Get the project URL and the **anon / publishable** key (never `service_role`).

Either set repo secrets on `itolmach/opera-companion`:

| Secret | Value |
| --- | --- |
| `SUPABASE_URL_PRODUCTION` | `https://ypblzqaltozesxxgcyha.supabase.co` |
| `SUPABASE_ANON_KEY_PRODUCTION` | the anon key |

…or simply commit both into the repo. They are public by design — they ship
inside the JavaScript bundle regardless, and Row Level Security is the actual
boundary. Committing them removes a step the user has to do by hand.

Then re-run the `Deploy to GitHub Pages` workflow on `main`.

### 4. Verify end to end

Load `https://itolmach.github.io/opera-companion/`, sign in with Google, add
something to the wishlist, reload, confirm it persists. Check it landed in
`list_items` with the right `user_id`.

---

## Still needs the user (dashboard only)

1. **GitHub Pages source** — Settings → Pages → *Deploy from a branch* →
   `gh-pages` → `/ (root)`. **Not** "GitHub Actions" as the source: that mode
   blocks non-default branches and would kill every preview later.
2. **Google OAuth** — Google Cloud Console → OAuth client (Web application),
   authorized redirect URI exactly:
   `https://ypblzqaltozesxxgcyha.supabase.co/auth/v1/callback`
   Then Supabase → Authentication → Providers → Google → paste client ID and
   secret. Then Authentication → URL Configuration:
   - Site URL: `https://itolmach.github.io/opera-companion/`
   - Redirect URLs: `https://itolmach.github.io/opera-companion/**` and
     `http://localhost:3000/**`

## Worth raising before real users

Free-tier projects pause after about a week idle. Once the site is genuinely
live that's an outage, not a theoretical risk — production should move to a
paid plan before anyone is pointed at it. The same upgrade frees a slot for
staging, which brings preview branches back.
