import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/l10n/app_localizations_it.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/app_back_button.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';
import 'package:cinemuse_app/shared/widgets/state_preview.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/focus_helpers.dart';

void main() {
  Future<void> pumpButton(
    WidgetTester tester,
    VoidCallback onTap, {
    Locale? locale,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(child: AppBackButton(onTap: onTap)),
        ),
      ),
    );
  }

  /// A page with the ← on top of a button, like the title page.
  Future<void> pumpPage(WidgetTester tester, VoidCallback onBack) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              AppBackButton(onTap: onBack),
              const SizedBox(height: 40),
              TextButton(onPressed: () {}, child: const Text('Play')),
            ],
          ),
        ),
      ),
    );
  }

  /// Moves the mouse far enough to count as using it.
  Future<void> moveMouse(WidgetTester tester, {double distance = 100}) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(400, 400));
    await mouse.moveBy(Offset(distance, 0));
    await mouse.removePointer();
    await tester.pump();
  }

  bool isShown(WidgetTester tester) =>
      tester.widget<Visibility>(find.byType(Visibility).first).visible;

  testWidgets('tap with the mouse calls onTap', (tester) async {
    var calls = 0;
    await pumpButton(tester, () => calls++);
    await moveMouse(tester);

    await tester.tap(find.byType(AppBackButton));
    await tester.pumpAndSettle();

    expect(calls, 1);
  });

  group('on the keys it hides, the mouse brings it back', () {
    testWidgets('starts hidden on the keys, as on a TV', (tester) async {
      await pumpButton(tester, () {});

      expect(isShown(tester), isFalse);
    });

    testWidgets('an arrow hides it, moving the mouse shows it', (tester) async {
      await pumpButton(tester, () {});
      await moveMouse(tester);
      expect(isShown(tester), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(isShown(tester), isFalse);

      await moveMouse(tester);
      expect(isShown(tester), isTrue);
    });

    testWidgets('a mouse bumped on the desk does not bring it back', (
      tester,
    ) async {
      await pumpButton(tester, () {});

      await moveMouse(tester, distance: 4);

      expect(isShown(tester), isFalse);
    });

    testWidgets('keeps its place while hidden: nothing moves', (tester) async {
      await pumpPage(tester, () {});
      final hidden = tester.getTopLeft(find.text('Play'));

      await moveMouse(tester);

      expect(isShown(tester), isTrue);
      expect(tester.getTopLeft(find.text('Play')), hidden);
    });

    testWidgets('hidden, a click on its place does nothing', (tester) async {
      var calls = 0;
      await pumpButton(tester, () => calls++);

      await tester.tapAt(tester.getCenter(find.byType(AppBackButton)));
      await tester.pumpAndSettle();

      expect(calls, 0);
    });

    testWidgets('hidden, Tab and the arrows skip it', (tester) async {
      await pumpPage(tester, () {});

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(isFocused(find.text('Play')), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(isFocused(find.text('Play')), isTrue);
    });

    testWidgets('the first arrow after the mouse never lands on it', (
      tester,
    ) async {
      await pumpPage(tester, () {});
      await moveMouse(tester);
      expect(isShown(tester), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(isFocused(find.text('Play')), isTrue);
      expect(isFocused(find.byIcon(Icons.arrow_back)), isFalse);
    });

    testWidgets('Up from the button right after the mouse stays on it', (
      tester,
    ) async {
      await pumpPage(tester, () {});
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(isFocused(find.text('Play')), isTrue);
      await moveMouse(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(isFocused(find.text('Play')), isTrue);
      expect(isFocused(find.byIcon(Icons.arrow_back)), isFalse);
    });
  });

  // The brand page shows the ring's look, keys or not (REV-252: round ring).
  testWidgets('a preview shows it, with a round ring', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: StatePreview(
              isFocused: true,
              child: AppBackButton(onTap: () {}),
            ),
          ),
        ),
      ),
    );

    expect(isShown(tester), isTrue);
    final ring = tester.widget<FocusRing>(find.byType(FocusRing));
    expect(ring.isVisible, isTrue);
    expect(ring.borderRadius, AppTheme.radiusFull);
  });

  // REV-253: the tooltip is in the app's language.
  for (final (locale, l10n) in [
    (const Locale('en'), AppLocalizationsEn()),
    (const Locale('it'), AppLocalizationsIt()),
  ]) {
    testWidgets('tooltip in ${locale.languageCode}', (tester) async {
      await pumpButton(tester, () {}, locale: locale);

      expect(find.byTooltip(l10n.commonGoBack), findsOneWidget);
    });
  }
}
