import 'package:cinemuse_app/features/navigation/presentation/window_buttons.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/l10n/app_localizations_it.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// REV-253: the window buttons have tooltips in the app's language.
void main() {
  const channel = MethodChannel('window_manager');

  Future<void> pumpButtons(
    WidgetTester tester, {
    required Locale locale,
    required bool isMaximized,
  }) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'isMaximized' ? isMaximized : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SizedBox(height: 32, child: AppWindowButtons()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (locale, l10n) in [
    (const Locale('en'), AppLocalizationsEn()),
    (const Locale('it'), AppLocalizationsIt()),
  ]) {
    testWidgets('tooltips in ${locale.languageCode}', (tester) async {
      await pumpButtons(tester, locale: locale, isMaximized: false);

      expect(find.byTooltip(l10n.windowMinimize), findsOneWidget);
      expect(find.byTooltip(l10n.windowMaximize), findsOneWidget);
      expect(find.byTooltip(l10n.commonClose), findsOneWidget);
    });

    testWidgets('maximised window: Restore in ${locale.languageCode}', (
      tester,
    ) async {
      await pumpButtons(tester, locale: locale, isMaximized: true);

      expect(find.byTooltip(l10n.windowRestore), findsOneWidget);
      expect(find.byTooltip(l10n.windowMaximize), findsNothing);
    });
  }
}
