import 'package:cinemuse_app/features/settings/presentation/widgets/setting_input.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/l10n/app_localizations_it.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// REV-253: the password eye has a tooltip in the app's language.
void main() {
  for (final (locale, l10n) in [
    (const Locale('en'), AppLocalizationsEn()),
    (const Locale('it'), AppLocalizationsIt()),
  ]) {
    testWidgets('eye tooltip in ${locale.languageCode}: show, then hide', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SettingInput(
                value: 'secret',
                isPassword: true,
                onSave: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip(l10n.commonShowPassword), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.commonShowPassword));
      await tester.pumpAndSettle();
      expect(find.byTooltip(l10n.commonHidePassword), findsOneWidget);
    });
  }
}
