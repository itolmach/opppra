# Current state — Opera project

Two apps, one Supabase project, one account and one dataset across both.

## Where things live

| Thing | Where |
| --- | --- |
| iOS app (OperaApp) | this repo, branch `claude/mobile-web-app-review-u37c2y` |
| Web app | **`itolmach/TolmachevFamily`, branch `opera`** |
| Database schema | this repo, `supabase/migrations/` |
| Web app (old home) | `itolmach/opera-companion` — history only, superseded |

The web app moved into the private workspace repo for code privacy and to keep
everything in one place. It publishes as a gated preview branch:

```
https://itolmach.github.io/TolmachevFamily/opera/
```

The password is recorded in `PASSWORDS.md` on TolmachevFamily's `main`.

> The gate is a client-side SHA-256 overlay — it stops the link being casually
> readable, it is not security. The repo is private; the published site is not.

## Supabase

| Project | ID | State | Role |
| --- | --- | --- | --- |
| Opera and Ballet Tracker | `ypblzqaltozesxxgcyha` | active | **production** — both apps |
| opera-companion | `inxcorxhhhoqmjkrjqjj` | paused | unused; future staging |
| tolmachev-family-budget | `qwazgxmlichidhcjkkhi` | active | unrelated |

URL: `https://ypblzqaltozesxxgcyha.supabase.co`

**Schema is applied and verified**: 9 tables, RLS enabled on every one, storage
buckets with owner-only policies, and the signup trigger that creates a profile
plus the two default lists. `handle_new_user()` had its public EXECUTE grant
revoked — as a SECURITY DEFINER function it was exposed over RPC to anonymous
callers.

Remaining advisor warnings are GraphQL schema *discoverability*, not data
access. Standard for any Supabase app with RLS; rows still return empty to
non-owners.

> **Free plan allows 2 active projects.** Both slots are taken, so no staging
> project exists. Free projects also pause after about a week idle — fine for a
> gated prototype, not fine once real people depend on it.

## What's left

1. **Google OAuth.** Google Cloud Console → OAuth client (Web application),
   authorized redirect URI exactly:
   `https://ypblzqaltozesxxgcyha.supabase.co/auth/v1/callback`
   Then Supabase → Authentication → Providers → Google → client ID + secret.
2. **Supabase redirect URLs** — these must match the *new* location:
   - Site URL: `https://itolmach.github.io/TolmachevFamily/opera/`
   - Redirect URLs: `https://itolmach.github.io/TolmachevFamily/opera/**`
     and `http://localhost:3000/**`
3. **Deploy the edge function** — `supabase/functions/delete-account/index.ts`.
   Account deletion needs the service-role key, so it can't run from a client.
4. **Verify end to end** — sign in, add to wishlist, reload, confirm it
   persists and landed in `list_items` with the right `user_id`.

Then the iOS app: its `OperaApp/Config/Config.xcconfig` needs the same project
URL and anon key, the `supabase-swift` package added in Xcode, and the Sign in
with Apple capability enabled.
