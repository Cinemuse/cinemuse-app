# Contributing

How to work on Cinemuse. How the code is organised: [docs/architecture.md](docs/architecture.md).

## Commands

Always run Flutter through FVM. After a fresh clone: `git config commit.template .gitmessage`.

| Task | Command |
|---|---|
| Get packages | `fvm flutter pub get` |
| Run with dev login | `fvm flutter run -d windows --dart-define-from-file=dev_login.json` |
| Format | `fvm dart format lib test integration_test test_driver` |
| Analyze | `fvm flutter analyze` |
| All tests | `fvm flutter test` |
| One real-app test | `fvm flutter test integration_test/<file>.dart -d windows --dart-define-from-file=dev_login.json` |
| Every screen at every size (on demand) | `fvm flutter test --run-skipped -t screen-sizes` |
| Regenerate `*.g.dart` (Drift) | `fvm dart run build_runner build --delete-conflicting-outputs` |
| Translations | `fvm flutter gen-l10n` |

- **Before every commit:** format, analyze with 0 issues, the full test suite with 0 failures.
- **Dev login:** a debug build run with `dev_login.json` (gitignored; template `dev_login.example.json`) shows a "Dev login" button. Test credentials never go in code or `.env`, because `.env` is bundled into builds.
- Generated files (`*.g.dart`, `app_localizations*.dart`) are never edited by hand.

## Tests

- **Logic** gets a unit test in `test/`, at the same path as the file in `lib/`. **What the user sees or does** gets a widget test or a real-app test. **SQL** gets a check on the local database ([backend.md](docs/backend.md#local-sql-checks)). **Server functions** get a Deno test next to the file.
- **A new test must fail on the old code.** Unit and widget tests never call the real Supabase or TMDB.
- **Never change a shared fake to make a test pass:** a fake shows how the real service answers.
- New cases go into the existing test file; a new test file is only for a new source file.
- Find widgets the way the user sees them (text, tooltip, icon, the app's own widget), never by layout widgets or styles. Focus checks use `test/helpers/focus_helpers.dart`.
- Width and overflow checks need the real font: `setUpAll(loadAppFont)`.
- **Every screen at every size** (`test/screen_sizes/`) opens the main screens on a phone, a phone held sideways, a tablet, a TV and the smallest window, in Italian, with made-up long names, and fails on anything that doesn't fit, an error, or a screen without its content. The everyday run skips it: run it before a release, after a Flutter upgrade and after a screen redesign.
- **Real-app tests** (`integration_test/`) run the real app on Windows against the real services, signed in with the dev login. Each uses a title the account never touched and undoes its changes. CI doesn't run them.
- The full suite takes a few minutes: while working, run only the files you touch, then the full suite once before committing.

## Code rules

Old code that breaks a rule is fixed when a change touches it, not in big rewrites. If a rule can't be followed, say why in the commit message.

- **One job per file.** Code moves to a new file only when the current file is well over ~400 lines or the code is a separate job; a long `build()` is split into widget classes.
- **Widgets only show and forward:** they read providers and call one notifier method per user action. No network, database or data sorting in a widget. Widgets never import from `data/`; `lib/shared/` never imports a feature.
- **No copy-paste:** shared logic goes in `application/` or `core/`.
- **Names say the role:** files end with `_screen`, `_sheet`, `_card`, `_provider`, `_repository`, `_service`…; no vague names (`Manager`, `Helper`, `Utils`).
- **Comments explain why,** not what. No commented-out code.
- **Riverpod:** hand-written `Notifier` / `AsyncNotifier`, no code generation; providers are `autoDispose` unless a comment says why not; `ref.watch` only while building, `ref.read` in callbacks; after an `await`, check `ref.mounted`. Dependencies come through providers, so tests can replace them.
- **Errors:** services and repositories throw an `AppFailure`; never turn a failure into `null` or an empty list (offline would look like "not found"); no empty `catch`; the UI shows errors through the error mapper, never the raw text. A failed save restores the old state and shows an error.
- **Logging:** only `AppLogger`, never secrets.
- **Data:** a title is always its TMDB id + media type; times are stored in UTC and shown local; every `Future` is awaited (or `unawaited` with a reason); every controller, subscription and timer is disposed.
- **Security:** no secrets in code; new tables get owner-only row-level security; user input goes into SQL and URLs only as parameters; never skip certificate checks.
- **Packages:** under ~100 lines, write it instead. A new package must be maintained and support Android, Windows and Linux. Every override in `pubspec.yaml` says why.
- **Removing** never asks "Are you sure?": it happens at once, with `AppSnackBar.showUndo` (one Undo time for the whole app, a device setting; Off shows no message and the removal is final at once). What can't come back (a file, a saved copy) is deleted only when the message closes without Undo.
- **UI:** all text in the `.arb` files (English and Italian); sizes from `Breakpoints`, colours and text styles from `AppTheme`; every control works with the arrows and Enter (`DpadFocusable`) and shows the shared focus ring; every icon-only button has a tooltip; errors use the shared error widgets. The building blocks: [architecture.md](docs/architecture.md#ui-building-blocks).

## Commits

- **One change = one commit,** with its test.
- **Message:** [Conventional Commits](https://www.conventionalcommits.org/), `type(area): description`, lowercase, under ~72 characters (types in `.gitmessage`).
- **Stage exact files,** never `git add -A`, and check them for secrets.
- **Push straight to `main`;** no pull requests. Never force-push or delete `main`.

## CI and releases

- **`ci.yml`:** format, analyze and tests on every push to `main`.
- **`release.yml`:** push a tag `vX.Y.Z`. It runs CI, builds the Android APKs, the Windows zip and the Linux `.tar.gz`, writes `SHA256SUMS` and publishes a GitHub release. The `.env` file comes from the `ENV_FILE` secret.
- **Release notes:** the tag's message is the release's text: what changed for the people using the app, in plain words, under a `## English` and a `## Italiano` title. The app shows every version newer than the installed one, newest first, in its own language. Tag with `git tag -a vX.Y.Z --cleanup=verbatim -F notes.md`: without `--cleanup=verbatim`, git deletes the `##` lines, and a release whose message lacks either title stops before anything is published.
