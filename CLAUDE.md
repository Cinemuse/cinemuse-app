# Cinemuse app

Flutter app (Dart ^3.11, Flutter 3.41.0 pinned via FVM in `.fvmrc`).
Riverpod for state, Supabase backend, Drift local database, Dio for HTTP, media_kit for playback. Languages: English + Italian.

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
fvm flutter analyze
fvm flutter test
fvm dart run build_runner build --delete-conflicting-outputs   # regenerate *.g.dart (Drift)
fvm dart format lib test integration_test test_driver scripts  # CI fails if code isn't formatted
```

CI (`.github/workflows/ci.yml`) runs format check + `flutter analyze` + `flutter test` on every push to `main`, and `release.yml` only builds if they pass. Analyze must report 0 issues (lint rules in `analysis_options.yaml`). `pubspec.lock` is committed: after changing `pubspec.yaml`, commit the updated lock file too.

`fvm flutter test` must pass with 0 failures (263 pass, 1 skipped: the Live TV channel-guide button test, pending a check of the TV layout; see `../audit/08-testing.md`).

## Git

- Conventional Commits: `type(area): description`, lowercase, imperative, under ~72 chars. Types and examples are in `.gitmessage`.
- Pushing directly to `main` is allowed. Never force push or delete `main` (protected by a ruleset).

## Supabase MCP (read-only)

- Run `list_tables` before writing queries.
- `execute_sql`: always name the columns (no `SELECT *`) and use `LIMIT 10` or less. Never dump full tables into context.
- For debugging, start with `get_advisors` and `query_logs`.
- Schema changes go through migrations in git, never through the MCP.

## Don't

- Don't read or follow `../.agents/` (old rules).
- Don't commit or print `.env` (secrets).
- Don't hand-edit generated files (`*.g.dart`, `lib/l10n/app_localizations*.dart`).
