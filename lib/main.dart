import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:cinemuse_app/core/presentation/app_shell.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/auth/presentation/auth_screen.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';

import 'package:intl/date_symbol_data_local.dart';
import 'package:cinemuse_app/core/data/sqlite_workaround.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/core/application/locale_service.dart';

import 'package:stack_trace/stack_trace.dart';
import 'package:cinemuse_app/core/presentation/navigation_providers.dart';
import 'package:cinemuse_app/core/presentation/intents.dart';
import 'package:cinemuse_app/core/presentation/widgets/offline_error_screen.dart';
import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  Chain.capture(() async {
    setupSqlite();
    WidgetsFlutterBinding.ensureInitialized();
    MediaKit.ensureInitialized();
    // Parallelize independent initializations
    await Future.wait([
      initializeDateFormatting(),
      dotenv.load(fileName: ".env"),
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      if (io.Platform.isWindows) windowManager.ensureInitialized(),
    ]);

    // System configurations
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    // Depends on dotenv being loaded
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );

    if (io.Platform.isWindows) {
      const windowOptions = WindowOptions(
        size: Size(1280, 720),
        minimumSize: Size(800, 600),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
        title: 'Cinemuse',
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    }
    
    // Custom error handling for Flutter errors to use terse stack traces
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (details.stack != null) {
        debugPrint(Chain.forTrace(details.stack!).terse.toString());
      }
    };

    runApp(const ProviderScope(child: CinemuseApp()));
  }, onError: (error, stackChain) {
    // This will print the error and the clean stack trace
    debugPrint(error.toString());
    debugPrint(stackChain.terse.toString());
  });
}

// BackIntent moved to lib/core/presentation/intents.dart

class CinemuseApp extends ConsumerWidget {
  const CinemuseApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final currentLocale = ref.watch(localeProvider);

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.escape): const BackIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): const BackIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          BackIntent: CallbackAction<BackIntent>(
            onInvoke: (intent) {
              // 1. Try popping the shell navigator (nested) first
              final shellNavigator = ref.read(shellNavigatorKeyProvider).currentState;
              if (shellNavigator != null && shellNavigator.canPop()) {
                shellNavigator.pop();
                return null;
              }

              // 2. Fallback to popping the root navigator
              final navigator = navigatorKey.currentState;
              if (navigator != null && navigator.canPop()) {
                navigator.pop();
              }
              return null;
            },
          ),
        },
        child: MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Cinemuse',
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
              data: (result) {
                if (result == ConnectivityResult.none) {
                  return const OfflineErrorScreen();
                }
                return ExcludeSemantics(child: child ?? const SizedBox());
              },
              loading: () => ExcludeSemantics(child: child ?? const SizedBox()),
              error: (_, __) => ExcludeSemantics(child: child ?? const SizedBox()),
            );
          },
          home: authState.when(
            data: (user) => user != null ? const AppShell() : const AuthScreen(),
            loading: () => const Scaffold(
              backgroundColor: AppTheme.primary,
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (e, s) => const AuthScreen(),
          ),
        ),
      ),
    );
  }
}
