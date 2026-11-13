# Running OperaApp against Neon

The app talks to two Neon services and has **no Swift package dependencies**.
Nothing to add in Xcode, nothing to resolve, nothing to keep up to date — the
whole client is `URLSession` and `Codable`. (The previous version expected
`supabase-swift`, which was never actually added to the project, so it could
not build.)

| | |
| --- | --- |
| Neon project | `steep-morning-66838900` ("opera-companion", org **Ivan**) |
| Database | `opera`, branch `main` |
| Data API | `https://ep-winter-meadow-bcl0qyhn.apirest.c-16.us-east-1.aws.neon.tech/opera/rest/v1` |
| Auth | `https://ep-winter-meadow-bcl0qyhn.neonauth.c-16.us-east-1.aws.neon.tech/opera/auth` |

## 1. Config.xcconfig

```bash
cp OperaApp/Config/Config.xcconfig.example OperaApp/Config/Config.xcconfig
```

Fill in the two URLs above. It is gitignored.

One trap: xcconfig treats `//` as a comment **anywhere in the line**, including
inside a URL. The example splits it as `https:/$()/` for that reason. Remove
that and the value silently becomes `https:`, and every request fails with
something that looks nothing like a config error.

## 2. Two settings in the Neon console

Neither can be set from the app, and the app does not work without them.

**Trusted origin.** Auth → trusted domains → add `operaapp://auth` (the value
of `NEON_AUTH_ORIGIN`). Better Auth checks the `Origin` header on every call
and refuses an unknown one with `INVALID_ORIGIN`. Only `localhost` is trusted
by default.

**Anonymous role.** Data API settings → anonymous role → `anonymous`. Without
it the Data API rejects *every* unauthenticated request with 401, so the
catalogue cannot be browsed before signing in. The `anonymous` Postgres role
already exists and already has the right grants; the Data API just has to be
told to use it.

## 3. Sign in with Apple

Two halves, and the Neon half is not done yet.

- **Xcode:** select the target → Signing & Capabilities → **+ Capability** →
  Sign in with Apple. There is no `.entitlements` file in the project yet;
  adding the capability creates one.
- **Neon:** Auth → OAuth providers → add Apple, with the Service ID, Team ID,
  Key ID and `.p8` key from your Apple Developer account. Until this exists
  the button is wired and will fail cleanly with "Sign in with Apple is not
  set up for this project yet" rather than a raw provider error.

Email and password sign-in works without any of this.

## 4. Signing

`DEVELOPMENT_TEAM` is already set to `ZFBA888K4E` and the bundle id is
`com.operaapp.OperaApp`. Deployment target is iOS 16.

## What works, and what does not

Verified by calling the live Data API directly with a real account — not from
the app, which has never been compiled (there is no Xcode in the environment
this was written in):

- Catalogue search by title, by translated title (Russian included) and by
  composer
- The profile, the two default lists, and attendance logs
- Row level security: a forged `user_id` on a write is refused with 403

**Not working yet:**

- **Photo upload** (`uploadTicketPhoto`) throws a 501. Supabase Storage is
  gone; Neon Object Storage replaces it but uploading needs a presigned URL,
  and presigning needs a credential that must not ship inside the app. That
  is a small Neon Function that does not exist yet.
- **Productions, venues, performances.** The tables exist and have never been
  populated — the playbill work went into `opera_houses` and
  `playbill_entries` instead, which the web app's Афиша reads. Those methods
  return empty rather than failing, so the views still build.

## The shared id, which matters

`opera_id` is the **`opera_works.id` uuid from our own catalogue**, and the
web app writes the same value. The old iOS build composed
`"\(composer.id)-\(work.id)"` from OpenOpus, which matched nothing the web app
ever wrote — so a work saved on the phone never appeared on the web. If you
change how operas are fetched, keep that id.
