# Cinemuse

Personal cinema guide: track movies, series and anime, stream them, and watch live TV.
Flutter app for **Android, Windows and Linux**, with a Supabase backend.

## Setup

1. Install [FVM](https://fvm.app). Flutter 3.41.0 is pinned in `.fvmrc`; always run Flutter through `fvm`.
2. Create `.env` in this folder (it is bundled as an asset and never committed):

   ```
   SUPABASE_URL=
   SUPABASE_ANON_KEY=
   TMDB_API_KEY=
   GITHUB_OWNER=
   GITHUB_REPO=
   ```

   `GITHUB_OWNER` / `GITHUB_REPO` point the in-app updater at this repo's releases.
3. `fvm flutter pub get`, then `fvm flutter run`.

## Development

```
fvm flutter analyze
fvm flutter test
fvm dart format lib test integration_test test_driver scripts
fvm dart run build_runner build --delete-conflicting-outputs   # regenerate *.g.dart
```

CI (`.github/workflows/ci.yml`) runs the format check, analyze and tests on every push.

## Project layout

- `lib/core/`: app-wide code (database, network, services, theme).
- `lib/features/<name>/`: one folder per area, split into `data/`, `domain/`, `application/`, `presentation/`.
- `lib/shared/widgets/`: reusable widgets.
- `lib/l10n/`: translations (English, Italian). Edit the `.arb` files.
- `packages/media_kit_video/`: patched copy of `media_kit_video` (see the comment in `pubspec.yaml`).
- `supabase/`: database migrations and edge functions.
- `scripts/telemetry/`: scraper health checks (real network), run daily by `.github/workflows/telemetry.yml`. By hand: `fvm flutter test scripts/telemetry`.

## Release

Push a tag like `v1.2.3`. `.github/workflows/release.yml` builds the Android APKs, a Windows zip and Linux `.tar.gz` / `.deb`, and publishes a GitHub release. The `.env` file comes from the `ENV_FILE` repository secret.
