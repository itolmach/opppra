Standards: `PLAYBOOK.md` in `itolmach/TolmachevFamily`. Read it first (attach the repo read-only and `git show origin/main:PLAYBOOK.md`); this file only adds what's particular to this repo.

# Opera, the iOS app

- **It ships through the App Store only.** There is no web version any more
  (TolmachevFamily task #141). Code is staged here on branches; what people
  get is the app.
- **Nobody builds this at a Mac.** A session has no Xcode and no Swift
  toolchain, and the person is mostly on an iPad. The `iOS build` workflow is
  the compiler: push, then read its run. Never report Swift as working
  because it reads well; say whether the run was green.
- **The backend is Neon**, project `steep-morning-66838900`, database `opera`:
  the Data API for rows, Managed Better Auth for accounts. Use the Neon
  connector for anything on the project itself. Its destructive tools need
  the person's yes each time. `NEON_SETUP.md` says how the app talks to it.
- **There is no secret in the app and none in this repo.**
  `OperaApp/Config/Config.xcconfig` is the one config file and holds public
  addresses only. Authorization is grants plus row level security. The App
  Store Connect key lives in GitHub's secret settings; a database connection
  string is fetched from the connector when needed and never written down.
- **The schema is written once, in `supabase/migrations/`,** and
  `scripts/port-to-neon.py` generates `neon/migrations/0001`, `0003` and
  `0004` from it. Edit the source and re-run; `0005` and `0006` are written
  by hand. Checks fail if the two drift.
- **An opera's id is `opera_works.id`,** the uuid from our own catalogue.
  Lists and logs are keyed on it.
- **Test accounts are `claude-...@example.com`** and are deleted when the
  check is done. Never touch a real account.
- **Tasks are issues in `itolmach/TolmachevFamily`** labelled `task` and
  `opera`, never files here.
