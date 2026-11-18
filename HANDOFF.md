# Current state — Opera project

> **Out of date since November 2026.** This describes the Supabase backend and
> the web app. The backend is now Neon (`NEON_SETUP.md`) and the product is
> the iOS app only (`README.md`). Kept for the history of the contract; the
> rules about the shared `opera_id` and row level security still hold.

Two apps, one Supabase project, one account and one dataset across both.

## Where things live

| Thing | Where |
| --- | --- |
| iOS app (OperaApp) | this repo, branch `claude/mobile-web-app-review-u37c2y` |
| Web app | **`itolmach/TolmachevFamily`, branch `opera`** |
| Database schema | this repo, `supabase/migrations/` |
| Web app (old home) | `itolmach/opera-companion` — history only, superseded |

The web app moved into the private workspace repo for code privacy and to keep
everything in one place. It publishes at:

```
https://itolmach.github.io/TolmachevFamily/opera/
```

The password overlay was removed on 2026-09-16 — the site is public, and it is
installable on an iPhone Home Screen (manifest plus Apple touch icons), which
a gate would have broken.

> The repo is private; the published site is not. Nothing shipped in the
> bundle is a secret: the Supabase anon key is designed to be public and RLS
> is the real boundary.

## Supabase

| Project | ID | State | Role |
| --- | --- | --- | --- |
| Opera and Ballet Tracker | `ypblzqaltozesxxgcyha` | active | **production** — both apps |
| opera-companion | `inxcorxhhhoqmjkrjqjj` | paused | unused; future staging |
| tolmachev-family-budget | `qwazgxmlichidhcjkkhi` | active | unrelated |

URL: `https://ypblzqaltozesxxgcyha.supabase.co`

**Schema is applied and verified**: RLS enabled on every table, storage
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

## Verified end to end

Driven in a real browser (Chromium) against the live site and the live
Supabase project, on 2026-09-13:

- The password gate unlocks and the catalogue renders — 1,257 works, every
  one with a composer portrait that loads.
- Sign-in on the production URL completes and lands back in the app.
- Adding a work to the wishlist writes to `list_items` under the right
  `user_id`, and survives a reload.
- RLS holds: `anon` reads back an empty set, a second account cannot see the
  first account's rows, and both a forged `user_id` insert (403) and an
  anonymous insert (401) are refused.
- The signup trigger creates the profile and both default lists.
- No console errors anywhere in the flow.

The test accounts used for this were deleted afterwards; `auth.users` and
every application table are empty and ready for real signups.

Three runtime bugs surfaced during that pass and are fixed on the `opera`
branch (commit "Fix sign-in freeze, broken images, and undefined work ids"):
signing in froze the tab in a request loop, every catalogue image was broken,
and every work was keyed `undefined-<title>` with 11 duplicate ids.

## What's left

1. **Google OAuth.** Google Cloud Console → OAuth client (Web application),
   authorized redirect URI exactly:
   `https://ypblzqaltozesxxgcyha.supabase.co/auth/v1/callback`
   Then Supabase → Authentication → Providers → Google → client ID + secret.
   Until then the "Continue with Google" button reports that it isn't set up;
   email sign-in is unaffected.
2. **Magic link delivery is untested.** The link is built and the redirect
   allow-list is right, but nothing here can read an inbox, so the one step
   still unproven is clicking a real emailed link. Supabase's built-in SMTP is
   also rate-limited to a handful of messages an hour — fine for you, not for
   real users. Point it at a real sender before anyone else signs up.
3. **Re-seed our own catalogue tables.** `opera_works` and friends hold the
   older, smaller catalogue. `scripts/seed-catalogue.mjs` re-imports the
   current one but needs `SUPABASE_SERVICE_ROLE_KEY`.
4. **Playbill coverage.** Three houses are readable (Mariinsky, Mikhailovsky,
   Novaya Opera). The Bolshoi answers an unattended request with 401 and
   Astana Opera renders its schedule in the browser; both need a headless
   browser, or a hand-maintained feed.
5. **Nothing refreshes the playbill on a schedule.** `npm run refresh-playbill`
   is run by hand. It wants `SUPABASE_SERVICE_ROLE_KEY`, which is why it is
   not in the deploy workflow — that key must never be in a client build.
   A scheduled GitHub Action with the key as a repo secret is the next step.

Then the iOS app: its `OperaApp/Config/Config.xcconfig` needs the same project
URL and anon key, the `supabase-swift` package added in Xcode, and the Sign in
with Apple capability enabled.

## Opera houses and the playbill

Added 2026-09-20 (`supabase/migrations/0004_opera_houses.sql`). This is the
half of "our own database" that 0003 does not cover: 0003 holds the works,
this holds where and when they are performed.

| Table | What it is |
| --- | --- |
| `opera_houses` | the houses, keyed by `slug` (`mariinsky`, `bolshoi`, …) |
| `playbill_entries` | one row per performance; public read, no client write |
| `user_saved_houses` | the houses a person wants to visit; owner-only |

`playbill_entries.opera_id` is the **same MusicBrainz work id** as
`attendance_logs.opera_id` — deliberately not a foreign key to `opera_works`,
because a house can announce a premiere no catalogue holds yet and that
performance still belongs on the bill.

The web app surfaces this at `/afisha` (the houses) and
`/afisha/theatre?slug=…` (one house's next twelve months). Those two pages are
**in Russian and styled on mariinsky.ru** — ivory grounds, a parchment band,
hairline bronze rules, PT Serif over PT Sans — because they are what a Russian
house would be shown. The rest of the app stays in English; the two surfaces
do not need to agree, and a German one would be a third.

Entries come from `scripts/fetch-playbill.mjs` in the web repo, which reads
each house's own site and keeps only what the house itself files as opera.
As of 2026-09-20: **115 performances, 109 linked to a catalogue work**, from
the Mariinsky (through October), the Mikhailovsky (through December) and
Novaya Opera (through March 2027). Each house publishes as far ahead as it
publishes; the twelve months is a ceiling, not a promise.

`opera_houses.timezone` is what playbill times are shown in. It is a fact
about the house, not the reader: formatted in the viewer's zone instead, the
Mariinsky's 19:00 performances read 16:00 from anywhere west of Moscow.

## The one contract between the two apps

Both apps write to the same `list_items` and `attendance_logs` rows, so a work
must carry the **same `opera_id`** in both or a title saved on the phone never
shows up on the web.

```
opera_id = the MusicBrainz work MBID     e.g. Khovanshchina -> 14ea1c96-ed3c-46fd-9bef-a025698dbd55
```

**This changed on 2026-09-14 and the iOS app has not caught up.** It still
builds `"\(composer.id)-\(work.id)"` from OpenOpus in `APIService.swift`,
which no longer matches anything the web app writes.

### Why the source changed

OpenOpus has no opera type. It files everything staged under genre `Stage` and
leaves `subtitle` empty on about 40% of works, so film scores and incidental
music were indistinguishable from real operas, and the catalogue could only be
cleaned with a denylist that was never going to be complete.

MusicBrainz types operas explicitly and its API filters on that type, so
there is no genre guessing. Wikidata supplies the translated titles on top,
joined exactly on the MusicBrainz work id (Wikidata property P435) rather than
by name. The web catalogue is now **2,490 operas, 545 with Russian titles**.

One trap, because iOS will hit it too: the broad `type:opera` search pages by
relevance, relevance ties shift between requests, and paging through it drops
about a quarter of each composer's works without any error. The web pipeline
now uses that search only to enumerate composers and then queries each
composer separately. Read from the broad search alone, the catalogue was
missing Pagliacci, Dido and Aeneas, Siegfried and Пиковая дама.

### What the iOS app has to change

1. **Fetch from MusicBrainz, not OpenOpus.**
   `https://musicbrainz.org/ws/2/work?query=type:opera&limit=100&offset=N&fmt=json`
   Their rules: one request per second, and a real contact address in the
   `User-Agent`. Going faster gets you throttled and then blocked.
2. **Use `work.id` (the MBID) as `opera_id`** — nothing derived, nothing
   concatenated.
3. **Drop excerpts.** MusicBrainz types arias and acts as operas too. The web
   app's two filters are in `scripts/fetch-and-process-data.mjs`
   (`findExcerpts`) and should be mirrored rather than reinvented.
4. **Composer comes from the `composer` relation**, not a field.
5. Expect **non-Latin titles and composer names** — Хованщина is stored in
   Cyrillic, and its composer as `Модест Петрович Мусоргский`. Any search must
   transliterate rather than assume Latin; see `src/lib/search.ts`.

The simplest correct option is for iOS to read the same generated
`all_operas.json` the web app publishes, rather than querying MusicBrainz
itself. That guarantees the two catalogues agree by construction, which is the
whole point of the shared id.
