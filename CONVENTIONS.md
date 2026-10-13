# Coding conventions

Rules for every change. Old code that breaks a rule is fixed only when a fix touches it (no big-bang rewrites). If a rule can't be followed, say why in the chat and in the commit message.

## Structure

- **One job per file.** Over ~400 lines → check whether the file does two jobs and split it. A file already over 400 lines must not grow: put new code in a new file.
- Functions over ~50 lines → split them. Long `build()` → extract small widget **classes** (not `_buildX()` methods).
- Layers: `presentation/` (widgets) → `application/` (providers, notifiers) → `data/` (repositories, API, Drift) → `domain/` (models). Widgets never import from `data/`.
- **Widgets only show and forward.** A widget reads providers, shows the state, and calls one notifier method per user action. Never in a widget: Supabase / Dio / Drift / TMDB calls, repository or service calls, sorting / filtering / merging data, `try/catch` around saves. Allowed: purely visual state (animations, focus, hover, scroll and text controllers).
- No copy-paste: if the same logic is needed twice, move it to one place (`application/` or `core/`).
- No new uses of `Supabase.instance` or other globals in providers: get dependencies through a provider so tests can override them.

## Naming

- File names end with their role: `_screen`, `_sheet`, `_card`, `_row`, `_tile` (widgets), `_provider(s)`, `_notifier`, `_repository`, `_service`, `_source` (scrapers), `_model`. The main class matches the file name.
- Providers end in `Provider`. Booleans start with `is` / `has` / `can` / `should`.
- No new vague names (`Manager`, `Helper`, `Utils`, `Handler`, `data`, `info`): name what it does.

## Comments

- Explain **why**, not what the code already says. Workarounds name the reason or the bug (`// media_kit drops the first frame on Windows`).
- `///` doc comment on public classes and methods in `core/` and on services/repositories.
- No commented-out code (git has it). A TODO carries an ID from the backlog: `// TODO(REV-230): …`.

## Riverpod

- New and changed state: `Notifier` / `AsyncNotifier` written by hand (no `@riverpod` codegen). Simple reads: `FutureProvider` / `StreamProvider` / `Provider`.
- No new `StateNotifier` or `StateProvider`. When a fix changes the logic of one, convert that one to `Notifier`.
- Providers are `autoDispose` (families always) unless they must live for the whole session; in that case write a one-line comment saying why.
- `ref.watch` only in `build()` (or a provider body); `ref.read` in callbacks. Use `select` when you need one field.
- A provider must not re-run on every playback progress tick: watch status changes only (PERF-02, REV-191).
- No hidden caches inside services (a private `Map` in a plain `Provider`): keep state in a provider so it can be invalidated, e.g. on logout.

## Errors

- Services and repositories throw an **`AppFailure`** (sealed, `lib/core/error/app_failure.dart`). Catch library errors (`DioException`, `PostgrestException`, `SocketException`, …) at that boundary and throw the matching failure, keeping the original as `cause`.
- No new `throw Exception('…')`, `throw '<string>'` or `AppException`. When a fix changes a function that throws one, switch it to `AppFailure`.
- **Never turn a failure into `null` or `[]`.** `null` / empty means "really not found / really empty"; offline or server errors must throw (REV-30).
- No empty `catch`. Every `catch` either rethrows (as `AppFailure`) or logs with `AppLogger` and says in a comment why it's safe to continue.
- Saves: the notifier `await`s the write; on failure it restores the old state and rethrows, and the UI shows a message (REV-78). No fire-and-forget saves.
- The UI shows errors through the error mapper (`lib/core/error/`) as translated text, never `e.toString()` (REV-164).

## Logging

- Log only with `AppLogger` (`lib/core/utils/app_logger.dart`). No new `debugPrint`, `print` or `developer.log`.
- Never log secrets: API keys, tokens, passwords, playlist URLs with credentials. Don't rely on the logger hiding them.

## Data rules

- **A title is `tmdbId` + media type**, never `tmdbId` alone (movie and TV IDs overlap). Queries, keys, maps and caches use both (REV-177).
- **Times**: send and store UTC (`toUtc()`), show `toLocal()` (REV-178).
- Async: every `Future` is `await`ed, or wrapped in `unawaited(...)` with a comment saying why (lint: `unawaited_futures`). After an `await` in a widget, check `mounted` / `context.mounted` before using `context` or `setState`.
- Dispose every controller, `StreamSubscription` and `Timer` you create.

## Security

- No keys, tokens or URLs with credentials in code: they come from `.env` (app) or `supabase secrets set` (edge functions).
- Every new table has RLS on, with policies limited to the owner (`auth.uid()`). Schema changes only through migrations.
- User input is never pasted into SQL or URLs as text: use query parameters / RPC arguments and `Uri` builders.

## Dependencies

- No new package without asking the user first. If the code needed is under ~100 lines, write it instead.
- A new package must be maintained (recent release, good pub.dev score) and support Android, Windows and Linux.
- Every `dependency_overrides` entry has a comment saying why. Commit `pubspec.lock` with `pubspec.yaml`.
- Version upgrades go in their own commit, never mixed with a fix (DEP-01).

## UI

- All text users see is in the `.arb` files (English + Italian). Includes error messages and titles (REV-15, REV-215).
- Screen sizes: use the shared breakpoint constants (REV-51); never write a new pixel number such as 600 / 768. Use `MediaQuery.sizeOf(context)`, not `MediaQuery.of(context).size`.
- **Works with a remote and a keyboard**: every control can be reached with the arrow keys and activated with Enter; exactly one tap handler per control (REV-39); the main button of a screen or dialog has `autofocus: true`. Check on Windows with arrows + Enter.
- **Hand cursor on everything clickable** (REV-246). `DpadFocusable` and the theme's buttons and menu items set it; a raw `InkWell` gets `mouseCursor: AppTheme.clickCursor`, and anything else clickable gets a `MouseRegion(cursor: SystemMouseCursors.click)`.
- No hard-coded colors or text styles: use the theme.

## Tests

- A fix to logic (`data/`, `domain/`, `application/`, providers) adds a test that **fails before the fix** and passes after. It goes in `test/`, at the same path as the file in `lib/`.
- UI, platform, config and SQL-only fixes and code deletions need no test: write in the chat how it was checked by hand.
- Tests never call the real Supabase or TMDB: override providers with fakes (`ProviderContainer(overrides: […])`).

## Before every commit

`fvm dart format lib test integration_test test_driver scripts` · `fvm flutter analyze` (0 issues) · `fvm flutter test` (0 failures).
