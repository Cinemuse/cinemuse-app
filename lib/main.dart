import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:cinemuse_app/features/navigation/presentation/app_shell.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/auth/presentation/auth_screen.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/core/services/system/app_full_screen.dart';
import 'package:cinemuse_app/core/services/system/phone_orientation.dart';

import 'package:intl/date_symbol_data_local.dart';
import 'package:cinemuse_app/core/data/sqlite_workaround.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/core/application/locale_service.dart';

import 'package:stack_trace/stack_trace.dart';
import 'package:cinemuse_app/features/navigation/application/back_navigation_notifier.dart';
import 'package:cinemuse_app/core/presentation/intents.dart';
import 'package:cinemuse_app/core/presentation/app_scroll_behavior.dart';
import 'package:window_manager/window_manager.dart';
import 'package:cinemuse_app/core/utils/platform_info.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:cinemuse_app/shared/widgets/back_key_release_guard.dart';
import 'package:cinemuse_app/shared/widgets/pointer_hiding_layer.dart';
import 'package:cinemuse_app/shared/widgets/screen_scale.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';
import 'package:cinemuse_app/features/settings/application/local_settings_service.dart';
import 'package:cinemuse_app/features/updates/data/linux_menu_entry.dart';

void main() {
  Chain.capture(
    () async {
      setupSqlite();
      WidgetsFlutterBinding.ensureInitialized();
      MediaKit.ensureInitialized();
      // Parallelize independent initializations
      await Future.wait([
        initializeDateFormatting(),
        dotenv.load(fileName: ".env"),
        PlatformInfo.initialize(),
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values,
        ),
        if (io.Platform.isWindows || io.Platform.isLinux)
          windowManager.ensureInitialized(),
      ]);

      // System configurations
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      );

      // Depends on dotenv being loaded
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
      );

      var startsFullScreen = false;
      if (io.Platform.isWindows || io.Platform.isLinux) {
        startsFullScreen = await LocalSettingsNotifier.readStartFullScreen();
        const windowOptions = WindowOptions(
          size: Size(1280, 720),
          // Narrower, the top bar and the Library stats don't fit.
          minimumSize: Size(900, 600),
          center: true,
          backgroundColor: Colors.transparent,
          skipTaskbar: false,
          titleBarStyle: TitleBarStyle.hidden,
          title: 'Cinemuse',
        );

        await windowManager.waitUntilReadyToShow(windowOptions, () async {
          // Linux taskbars show the window's own picture; on Windows the
          // logo is built into the program file. A small copy, because X11
          // silently refuses a window icon over about 250 x 250.
          if (io.Platform.isLinux) {
            await windowManager.setIcon('assets/logo-128.png');
          }
          // Before showing, so a window never flashes first.
          if (startsFullScreen) await windowManager.setFullScreen(true);
          await windowManager.show();
          await windowManager.focus();
        });
      }

      // A debug build is run from the code folder and isn't the installed app.
      // Not awaited: the app shouldn't wait for it, and it never throws.
      if (io.Platform.isLinux && !kDebugMode) {
        unawaited(
          addLinuxMenuEntry(
            exePath: io.Platform.resolvedExecutable,
            environment: io.Platform.environment,
          ),
        );
      }

      // Custom error handling for Flutter errors to use terse stack traces
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        if (details.stack != null) {
          debugPrint(Chain.forTrace(details.stack!).terse.toString());
        }
      };

      runApp(
        ProviderScope(
          retry: noProviderRetry,
          overrides: [
            if (startsFullScreen)
              appFullScreenProvider.overrideWith(
                () => AppFullScreenNotifier(startsOn: true),
              ),
          ],
          child: const CinemuseApp(),
        ),
      );
      PhoneOrientation.initializeWhenSized();
    },
    onError: (error, stackChain) {
      // This will print the error and the clean stack trace
      debugPrint(error.toString());
      debugPrint(stackChain.terse.toString());
    },
  );
}

class CinemuseApp extends ConsumerWidget {
  const CinemuseApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final currentLocale = ref.watch(localeProvider);
    // The Undo time is a device setting: listening loads it when the app
    // opens, so the first removal already uses it.
    ref.listen(
      localSettingsProvider.select((s) => s.undoTime),
      (_, time) => AppSnackBar.undoDuration = time,
    );
    final screenPercent = ref.watch(
      localSettingsProvider.select((s) => s.screenPercent),
    );

    return BackKeyReleaseGuard(
      child: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.escape): const BackIntent(),
          const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true):
              const BackIntent(),
          const SingleActivator(LogicalKeyboardKey.f11):
              const ToggleFullScreenIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            BackIntent: CallbackAction<BackIntent>(
              onInvoke: (intent) {
                // A page above the shell (on the root navigator) is the one
                // on screen, so it closes first.
                final navigator = navigatorKey.currentState;
                if (navigator != null && navigator.canPop()) {
                  navigator.pop();
                  return null;
                }
                // Keyboard shortcut: never closes the app.
                ref
                    .read(backNavigationProvider.notifier)
                    .handleBack(canExitApp: false);
                return null;
              },
            ),
            ToggleFullScreenIntent: CallbackAction<ToggleFullScreenIntent>(
              onInvoke: (intent) =>
                  ref.read(appFullScreenProvider.notifier).toggle(),
            ),
          },
          child: MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Cinemuse',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            scrollBehavior: const AppScrollBehavior(),
            locale: currentLocale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            // Around the navigator: every page, sheet and menu is resized too.
            // A phone has no Screen size row: the system's text size does
            // that job, so a size saved before is left out.
            builder: (context, child) => ScreenScale(
              scale:
                  PhoneOrientation.isPhoneScreen(
                    isAndroid: defaultTargetPlatform == TargetPlatform.android,
                    isTV: PlatformInfo.isTV,
                    screen: MediaQuery.sizeOf(context),
                  )
                  ? 1
                  : screenPercent / 100,
              child: PointerHidingLayer(
                child: AppSnackBarHost(child: child ?? const SizedBox()),
              ),
            ),
            home: authState.when(
              data: (user) =>
                  user != null ? const AppShell() : const AuthScreen(),
              loading: () => const Scaffold(
                backgroundColor: AppTheme.primary,
                body: Center(child: CircularProgressIndicator()),
              ),
              error: (e, s) => const AuthScreen(),
            ),
          ),
        ),
      ),
    );
  }
}
