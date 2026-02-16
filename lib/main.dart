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
import 'package:cinemuse_app/core/services/supabase_service.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/core/application/locale_service.dart';

import 'package:stack_trace/stack_trace.dart';

void main() {
  Chain.capture(() async {
    WidgetsFlutterBinding.ensureInitialized();
    MediaKit.ensureInitialized();
    
    await dotenv.load(fileName: ".env");

    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
    
    // Custom error handling for Flutter errors to use terse stack traces
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (details.stack != null) {
        print(Chain.forTrace(details.stack!).terse);
      }
    };

    runApp(const ProviderScope(child: CinemuseApp()));
  }, onError: (error, stackChain) {
    // This will print the error and the clean stack trace
    print(error);
    print(stackChain.terse);
  });
}

class BackIntent extends Intent {
  const BackIntent();
}

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
          builder: (context, child) => ExcludeSemantics(child: child ?? const SizedBox()),
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
