# Cinemuse app

Flutter app (Dart ^3.11, Flutter 3.41.0 pinned via FVM in `.fvmrc`). Platforms: Android, Windows, Linux only (no iOS, macOS, Web).
Riverpod for state, Supabase backend, Drift local database, Dio for HTTP, media_kit for playback. Languages: English + Italian.

**Before writing or changing code, read [`CONVENTIONS.md`](CONVENTIONS.md)** (coding rules: structure, naming, Riverpod, errors, logging, security, dependencies, tests).

## Structure

- `lib/main.dart`: entry point
- `lib/core/`: shared code (`data/` Drift DB, `network/`, `services/`, `models/`, `error/`, `utils/`, `constants/`, `presentation/`, `application/`)
- `lib/features/<name>/`: one folder per area (auth, explore, home, live_tv, media, navigation, profile, search, settings, video_player), split into `data/`, `domain/`, `application/`, `presentation/`
- `lib/shared/widgets/`: reusable widgets
- `lib/l10n/`: translations. Edit the `.arb` files; `app_localizations*.dart` is generated.
- `packages/media_kit_video/`: local patched copy, used via `dependency_overrides` in `pubspec.yaml`
- `test/`, `integration_test/`: tests. `.github/workflows/`: release + telemetry.

## Commands (Windows: PowerShell, always prefix with `fvm`)

```powershell
fvm flutter pub get
fvm flutter run
fvm flutter run --dart-define-from-file=dev_login.json   # debug "Dev login" button (account in the uncommitted dev_login.json, see dev_login.example.json)
fvm flutter analyze
fvm flutter test
fvm dart run build_runner build --delete-conflicting-outputs   # regenerate *.g.dart (Drift)
fvm dart format lib test integration_test test_driver scripts  # CI fails if code isn't formatted
```

CI (`.github/workflows/ci.yml`) runs format check + `flutter analyze` + `flutter test` on every push to `main`, and `release.yml` only builds if they pass. Analyze must report 0 issues (lint rules in `analysis_options.yaml`). `pubspec.lock` is committed: after changing `pubspec.yaml`, commit the updated lock file too.

`fvm flutter test` must pass with 0 failures (618 pass on 2026-10-15).

## Tests

A fix that changes what the user sees or does comes with an automatic test, written and run by Claude (rules in `../PROJECT.md` → Tests, the list still to write in `../AUTO-TESTS.md`).

- **Widget test** (`test/`, same path as the file in `lib/`): one screen or widget in memory, no network. Override the providers with fakes (`ProviderScope(overrides: [...])`); Italian via `MaterialApp(locale: Locale('it'))` (+ `initializeDateFormatting` for dates); window size via `tester.view.physicalSize`. Example: `test/features/media/presentation/person_details_screen_test.dart`. Runs with `fvm flutter test` and in CI.
- **Real-app test** (`integration_test/`): the real app on Windows, real Supabase + TMDB, signed in as the **dev account** from `dev_login.json`. `pumpAppAndLogin` (in `app_test_helpers.dart`) starts the app and signs in; `pumpUntil` waits for network data. Each test first checks the account has nothing for the title it uses (stops otherwise), then undoes what it did with `addTearDown`. Example: `integration_test/episode_tick_test.dart`. Not run by `fvm flutter test` or CI; run each file by hand:

```powershell
fvm flutter test integration_test/episode_tick_test.dart -d windows --dart-define-from-file=dev_login.json
```

It builds the Windows app first (~1 min) and opens a window that may stay white (it only draws when the test pumps a frame): don't click in it. The `perf_*` files are performance benchmarks run with `flutter drive` (see their header), not checks.
- Check a new test catches the bug: break the code on purpose (or stash the fix), run it, see it fail, restore.

## Git

- Conventional Commits: `type(area): description`, lowercase, imperative, under ~72 chars. Types and examples are in `.gitmessage`.
- Pushing directly to `main` is allowed. Never force push or delete `main` (protected by a ruleset).
- Never add a `Co-Authored-By: Claude` line (or any other Claude attribution) to commit messages.
- When a piece of work is ready to commit, Claude runs `git add` on exactly those files (never `git add -A` or `.`), shows `git status`, then gives the user a ready-to-paste `git commit -m "..."` command. The user runs the commit and the push themselves. Before staging, check the files for secrets.

## Supabase MCP (read-only)

- Run `list_tables` before writing queries.
- `execute_sql`: always name the columns (no `SELECT *`) and use `LIMIT 10` or less. Never dump full tables into context.
- For debugging, start with `get_advisors` and `query_logs`.
- Schema changes go through migrations in git, never through the MCP.

## Database changes (Supabase CLI)

Migrations live in `supabase/migrations/` (baseline: `20261009215049_remote_schema.sql`). Docker must be running for local commands.

1. `supabase migration new <name>` → write the SQL.
2. `supabase start` (if not running), then `supabase migration up --local` → test in the local DB (Studio: http://127.0.0.1:54323).
3. `supabase db push --linked --dry-run` → check that only the new file is listed.
4. `supabase db push --linked` → apply to production. Commit the migration file.

Don't change the live schema by hand in the dashboard: it makes git and the database drift apart.

Edge functions (`supabase/functions/`: `sync-agenda`, `live-tv-resolver`):
- Deploy one at a time: `supabase functions deploy <name> --use-api`. `config.toml` keeps `verify_jwt = false` for both (same as production).
- Secrets (e.g. `TMDB_API_KEY`) are set with `supabase secrets set`, never hard-coded.
- `sync-agenda` replies `success: true` even when TMDB calls fail. To test it, check `upcoming_agenda_cache.updated_at`.
- Gotcha: `trigger_sync_agenda()` and the cron job hard-code the **production** function URL, so writing `watch_history`/`list_items` rows in the **local** DB calls the real edge function (backlog: BE-06 Vault).

## Don't

- Don't read or follow `../.agents/` (old rules).
- Don't commit or print `.env` (secrets).
- Don't hand-edit generated files (`*.g.dart`, `lib/l10n/app_localizations*.dart`).
