import 'dart:async';

import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/navigation/application/back_navigation_notifier.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/settings/presentation/settings_screen.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/app_font.dart';
import '../../../helpers/cursor_helpers.dart';
import '../../../helpers/focus_helpers.dart';

class _FakeSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();
}

/// Both debrid services on: Integrations shows the preferred-debrid choice.
class _BothDebridSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() =>
      const UserSettings(enableRealDebrid: true, enableTorBox: true);
}

/// Saves straight into its state: the row tests check what a tap saved.
class _SavingSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();

  @override
  Future<void> updateSettings(
    UserSettings Function(UserSettings current) change,
  ) async => state = change(state);
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

  // REV-246: the Settings rows showed the arrow cursor.
  testWidgets('every Settings category row: the hand', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith(_FakeSettingsNotifier.new)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SettingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final categories = find.descendant(
      of: find.byType(ListView).first,
      matching: find.byType(InkWell),
    );
    // Identity, Customization, Live TV, Integrations.
    expect(categories, findsNWidgets(4));
    for (var i = 0; i < 4; i++) {
      await expectHandOver(tester, categories.at(i));
    }
  });

  // REV-302: the drop-downs and their options showed the arrow cursor.
  final l10n = AppLocalizationsEn();
  for (final c in [
    (
      category: l10n.settingsCustomization,
      shown: l10n.settingsEnglish,
      option: l10n.settingsItalian,
    ),
    (
      category: l10n.settingsIntegrations,
      shown: 'Real-Debrid',
      option: 'TorBox',
    ),
  ]) {
    testWidgets('${c.category}: the drop-downs and their options show the '
        'hand', (tester) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(_BothDebridSettingsNotifier.new),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SettingsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(c.category).first);
      await tester.pumpAndSettle();

      final dropdowns = find.byWidgetPredicate((w) => w is DropdownButton);
      expect(dropdowns, findsWidgets);
      for (var i = 0; i < dropdowns.evaluate().length; i++) {
        await expectHandOver(tester, dropdowns.at(i));
      }
      await tester.tap(
        find.ancestor(of: find.text(c.shown), matching: dropdowns).first,
      );
      await tester.pumpAndSettle();
      await expectHandOver(tester, find.text(c.option).last);
    });
  }

  group('settings rows (REV-84b, REV-263)', () {
    late ProviderContainer container;

    Future<void> openCategory(WidgetTester tester, String category) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      FocusRing.debugWatchKeys();
      container = ProviderContainer(
        overrides: [settingsProvider.overrideWith(_SavingSettingsNotifier.new)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SettingsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(category).first);
      await tester.pumpAndSettle();
    }

    bool isRingShownAround(WidgetTester tester, Finder target) => tester
        .widgetList<FocusRing>(
          find.ancestor(of: target, matching: find.byType(FocusRing)),
        )
        .any((ring) => ring.isVisible);

    /// Tab until the focus is inside a [T] (a slider or a text box keeps
    /// its focus inside, so `isFocused` can't see it).
    Future<void> tabInto<T extends Widget>(WidgetTester tester) async {
      bool isIn() =>
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<T>() !=
          null;
      for (var i = 0; i < 40 && !isIn(); i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(isIn(), isTrue, reason: 'Tab never reached a $T');
    }

    final l10n = AppLocalizationsEn();
    for (final c in [
      (
        category: l10n.settingsCustomization,
        row: l10n.settingsShowSubtitles,
        value: (UserSettings s) => s.showSubtitles,
      ),
      (
        category: l10n.settingsIntegrations,
        row: l10n.settingsEnableVixSrc,
        value: (UserSettings s) => s.enableVixSrc,
      ),
    ]) {
      testWidgets('${c.row}: a click on the label flips the switch', (
        tester,
      ) async {
        await openCategory(tester, c.category);
        final before = c.value(container.read(settingsProvider));

        await tester.tap(find.text(c.row));
        await tester.pumpAndSettle();

        expect(c.value(container.read(settingsProvider)), !before);
      });

      testWidgets('${c.row}: Tab stops on the row, shows the ring, and '
          'Enter flips the switch', (tester) async {
        await openCategory(tester, c.category);
        final before = c.value(container.read(settingsProvider));

        await tabTo(tester, find.text(c.row));
        await tester.pumpAndSettle();
        expect(isRingShownAround(tester, find.text(c.row)), isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(c.value(container.read(settingsProvider)), !before);
        // Still on the row: the switch is not a stop of its own.
        expect(isFocused(find.text(c.row)), isTrue);
      });
    }

    for (final c in [
      (
        name: 'slider',
        category: l10n.settingsCustomization,
        tabIn: (WidgetTester t) => tabInto<Slider>(t),
        target: find.byType(Slider),
      ),
      (
        name: 'text box',
        category: l10n.settingsIdentity,
        tabIn: (WidgetTester t) => tabInto<TextField>(t),
        target: find.byType(TextField),
      ),
    ]) {
      testWidgets('a ${c.name} reached with Tab shows the ring', (
        tester,
      ) async {
        await openCategory(tester, c.category);

        await c.tabIn(tester);
        await tester.pumpAndSettle();

        final focused = FocusManager.instance.primaryFocus!.context!;
        expect(
          find
              .ancestor(
                of: find.byElementPredicate((e) => e == focused),
                matching: find.byWidgetPredicate(
                  (w) => w is FocusRing && w.isVisible,
                ),
              )
              .evaluate(),
          isNotEmpty,
        );
        expect(c.target, findsWidgets);
      });
    }
  });
}
