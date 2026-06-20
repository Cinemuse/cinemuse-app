/// Shared helpers for Cinemuse integration/performance tests.
///
/// Bootstraps the full app with all required initializations
/// (dotenv, Supabase, MediaKit, SQLite, HTTP overrides) and
/// authenticates via direct [AuthService.signIn] call — no UI
/// interaction needed, which allows running in profile mode.
library;

import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:cinemuse_app/core/data/sqlite_workaround.dart';
import 'package:cinemuse_app/core/network/http_overrides.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/core/presentation/app_shell.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/shared/widgets/carousels/poster_carousel_row.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/core/application/locale_service.dart';
import 'package:cinemuse_app/core/presentation/navigation_providers.dart';
import 'package:cinemuse_app/core/presentation/intents.dart';
import 'package:cinemuse_app/core/services/system/connectivity_service.dart';

/// Global [ProviderContainer] for direct provider access in tests.
late ProviderContainer testContainer;

/// Guards against re-initializing singletons across multiple tests
/// in the same process (Supabase, SQLite, MediaKit are all singletons).
bool _initialized = false;

/// One-time initialization of all singletons.
///
/// Safe to call multiple times — only runs once per process.
Future<void> _ensureInitialized() async {
  if (_initialized) return;

  io.HttpOverrides.global = AppHttpOverrides();
  setupSqlite();
  MediaKit.ensureInitialized();

  await Future.wait([
    initializeDateFormatting(),
    dotenv.load(fileName: '.env'),
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    ),
  ]);

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  _initialized = true;
}

/// Initializes the app, authenticates, and waits for the home screen
/// to be fully loaded with real data.
///
/// Returns the [ProviderContainer] for direct provider manipulation
/// (e.g., tab switching in navigation tests).
Future<ProviderContainer> pumpAppAndLogin(WidgetTester tester) async {
  await _ensureInitialized();

  // Create a fresh container for this test
  testContainer = ProviderContainer();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: testContainer,
      child: const _PerfTestApp(),
    ),
  );

  // Authenticate directly — works in both debug and profile mode
  final authService = testContainer.read(authProvider.notifier);
  await authService.signIn('aaa@aaa.aa', 'Password');

  // Wait for auth state to propagate and home screen to render
  await tester.pumpAndSettle(const Duration(seconds: 1));

  return testContainer;
}

/// Waits until at least one [PosterCarouselRow] is visible,
/// indicating that real TMDB data has arrived and rendered.
///
/// Times out after [timeout] with a descriptive error.
Future<void> waitForHomeData(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final stopwatch = Stopwatch()..start();

  while (stopwatch.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 500));

    final carousels = find.byType(PosterCarouselRow);
    if (carousels.evaluate().isNotEmpty) {
      // Found data — pump once more to let images start loading
      await tester.pump(const Duration(seconds: 1));
      return;
    }
  }

  throw TimeoutException(
    'Home screen data did not load within ${timeout.inSeconds}s. '
    'No PosterCarouselRow found. Check network connectivity and API keys.',
  );
}

/// Minimal app shell for performance tests.
///
/// Replicates [CinemuseApp] structure without debug-only features
/// like the window manager setup (not needed for perf tests).
class _PerfTestApp extends ConsumerWidget {
  const _PerfTestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final currentLocale = ref.watch(localeProvider);

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.escape): const BackIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          BackIntent: CallbackAction<BackIntent>(
            onInvoke: (intent) {
              final shellNavigator =
                  ref.read(shellNavigatorKeyProvider).currentState;
              if (shellNavigator != null && shellNavigator.canPop()) {
                shellNavigator.pop();
              }
              return null;
            },
          ),
        },
        child: MaterialApp(
          title: 'Cinemuse Perf Test',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          locale: currentLocale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            final connectivity = ref.watch(connectivityProvider);
            return connectivity.when(
              data: (_) => ExcludeSemantics(child: child ?? const SizedBox()),
              loading: () =>
                  ExcludeSemantics(child: child ?? const SizedBox()),
              error: (_, __) =>
                  ExcludeSemantics(child: child ?? const SizedBox()),
            );
          },
          home: authState.when(
            data: (user) => user != null
                ? const AppShell()
                : const Scaffold(
                    backgroundColor: AppTheme.primary,
                    body: Center(
                      child: Text(
                        'Waiting for auth...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
            loading: () => const Scaffold(
              backgroundColor: AppTheme.primary,
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (e, s) => Scaffold(
              backgroundColor: AppTheme.primary,
              body: Center(
                child: Text(
                  'Auth error: $e',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Exception thrown when a test operation exceeds its timeout.
class TimeoutException implements Exception {
  final String message;
  const TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
