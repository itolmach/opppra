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

## 1. Configuration

`OperaApp/Config/Config.xcconfig` holds the three addresses the app needs and
is committed. None of them is a secret: they are the same public endpoints
that ship inside the app, and the Data API takes no API key.

One trap: xcconfig treats `//` as a comment **anywhere in the line**, including
inside a URL. The file writes `https:/$()/` for that reason. Remove that and
the value silently becomes `https:`, and every request fails with something
that looks nothing like a config error. The Checks workflow guards it.

## 2. How a signed-out request works

Neon's Data API never accepts a request with no token. A visitor who has not
signed in fetches a short-lived token from `GET {auth}/token/anonymous`
(role `anonymous`, an hour) and sends it as `Authorization: Bearer`; what
that role may read is decided by grants and row level security. `NeonClient`
does this and caches the token. Sending nothing is a 401 whatever the Data
API's settings say.

Checked against the live project with an anonymous token: the catalogue,
houses and playbill read; private tables return no rows; every write and the
bootstrap function are refused with 403.

## 3. The Origin header

Better Auth checks the `Origin` header on every auth call and refuses an
unknown one with `INVALID_ORIGIN`. Neon only accepts http(s) origins on its
trusted list, so a custom scheme such as `operaapp://` cannot be used. The
app sends `https://itolmach.github.io`, which is on the list. It is only a
registered name; nothing has to be served there.

Checked: sign-up and the token exchange succeed with that origin, and an
unlisted origin is refused with 403.

## 4. Sign in with Apple

The app side is done: the entitlement is in
`OperaApp/Config/OperaApp.entitlements` and the button sends Apple's identity
token to `sign-in/social`. The Neon side is not: the Apple provider has to be
added to the project (Neon console -> Auth -> OAuth providers) with a Services
ID, the Team ID, a Key ID and the `.p8` key from the Apple Developer account.
Those are secrets, so they are typed into Neon's console by the account
holder and never pass through a chat or this repo. Until then the button
fails cleanly with "Sign in with Apple is not set up for this project yet".

Open question, to settle on the first real attempt: a native sign-in's token
names the app's bundle id as its audience, while Neon's form asks for a
Services ID. If the token is refused for its audience, the bundle id is the
value to try as the client id.

Email and password sign-in works without any of this.

## 5. Building and shipping

Nothing here needs a Mac. `ios-build.yml` compiles the app for the simulator
on every push that touches it. `testflight.yml`, started by hand, archives,
signs with Apple's cloud-managed signing and uploads to TestFlight; the three
secrets it needs are listed at the top of that file. It has not been run yet.

`DEVELOPMENT_TEAM` is `ZFBA888K4E`, the bundle id is `com.operaapp.OperaApp`,
and the deployment target is iOS 16.

## What works, and what does not

Verified by calling the live Data API directly with a real account, not from
the app on a device:

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
