import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/l10n/app_localizations_it.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/app_back_button.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('tap calls onTap', (tester) async {
    var calls = 0;
    await pumpButton(tester, () => calls++);

    await tester.tap(find.byType(AppBackButton));
    await tester.pumpAndSettle();

    expect(calls, 1);
  });

  testWidgets('Enter on the focused button calls onTap', (tester) async {
    var calls = 0;
    await pumpButton(tester, () => calls++);

    // Tab moves focus to the first focusable control: the back button.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(calls, 1);
  });

  // REV-252: the round button gets a round ring.
  testWidgets('focused button shows a round ring', (tester) async {
    await pumpButton(tester, () {});

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

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
