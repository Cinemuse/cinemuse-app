import 'dart:async';

import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/navigation/application/back_navigation_notifier.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/presentation/settings_screen.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/app_font.dart';

class _FakeSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();
}

void main() {
  setUpAll(loadAppFont);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Back on a phone (REV-86)', () {
    late GlobalKey<NavigatorState> shellNavigator;

    /// The app shell's Back wiring: pages open in the shell navigator, and
    /// the phone's Back button goes to the one Back handler.
    Future<void> pumpShell(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsProvider.overrideWith(_FakeSettingsNotifier.new)],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) {
                shellNavigator = ref.watch(shellNavigatorKeyProvider);
                return PopScope(
                  canPop: false,
                  onPopInvokedWithResult: (didPop, _) {
                    if (didPop) return;
                    ref
                        .read(backNavigationProvider.notifier)
                        .handleBack(canExitApp: true);
                  },
                  child: Navigator(
                    key: shellNavigator,
                    onGenerateRoute: (settings) => MaterialPageRoute(
                      settings: settings,
                      builder: (_) => const Scaffold(body: Text('Home tab')),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    Future<void> pressBack(WidgetTester tester) async {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }

    Future<void> open(
      WidgetTester tester,
      NavigatorState navigator,
      Widget page,
    ) async {
      // Done only when the page closes.
      unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => page)));
      await tester.pumpAndSettle();
    }

    testWidgets('in a category, Back shows the category list; Back again '
        'closes Settings', (tester) async {
      await pumpShell(tester);
      await open(tester, shellNavigator.currentState!, const SettingsScreen());
      await tester.tap(find.text('App Customization'));
      await tester.pumpAndSettle();
      expect(find.text('Show Subtitles'), findsOneWidget);
      expect(find.text('Live TV'), findsNothing);

      await pressBack(tester);

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Show Subtitles'), findsNothing);
      expect(find.text('Live TV'), findsOneWidget);

      await pressBack(tester);

      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.text('Home tab'), findsOneWidget);
    });

    testWidgets('Back still closes a page in the shell (details)', (
      tester,
    ) async {
      await pumpShell(tester);
      await open(
        tester,
        shellNavigator.currentState!,
        const Scaffold(body: Text('Details page')),
      );

      await pressBack(tester);

      expect(find.text('Details page'), findsNothing);
      expect(find.text('Home tab'), findsOneWidget);
    });

    testWidgets('Back still closes a page over the shell (player)', (
      tester,
    ) async {
      await pumpShell(tester);
      await open(
        tester,
        tester.state<NavigatorState>(find.byType(Navigator).first),
        const Scaffold(body: Text('Player page')),
      );

      await pressBack(tester);

      expect(find.text('Player page'), findsNothing);
      expect(find.text('Home tab'), findsOneWidget);
    });
  });
}
