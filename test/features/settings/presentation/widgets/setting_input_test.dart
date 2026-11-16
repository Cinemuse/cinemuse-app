import 'package:cinemuse_app/features/settings/presentation/widgets/setting_input.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/l10n/app_localizations_it.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

import '../../../../helpers/focus_helpers.dart';

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
          retry: noProviderRetry,
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

  testWidgets('with the remote: Enter types, the keyboard Done stops on the '
      'box without saving, Right reaches Save', (tester) async {
    final saved = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SettingInput(value: 'old', onSave: (v) async => saved.add(v)),
          ),
        ),
      ),
    );
    final box = find.byType(TextField);
    bool isTyping() => tester.widget<TextField>(box).focusNode!.hasFocus;
    final save = find.text(AppLocalizationsEn().settingsSave);

    await tabTo(tester, box);
    expect(isTyping(), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(isTyping(), isTrue);

    tester.testTextInput.enterText('new');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(isTyping(), isFalse);
    expect(isFocused(box), isTrue);
    expect(saved, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(isFocused(save), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(saved, ['new']);
    // The "Saved" tick goes after two seconds.
    await tester.pump(const Duration(seconds: 2));
  });
}
