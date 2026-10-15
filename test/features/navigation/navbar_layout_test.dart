import 'package:cinemuse_app/features/navigation/presentation/navbar.dart';
import 'package:cinemuse_app/features/navigation/presentation/window_buttons.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/l10n/app_localizations_it.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// REV-51: the navbar layout follows the shell's width rule on every
// platform; only the window buttons depend on the platform.
void main() {
  Future<void> pumpNavbar(
    WidgetTester tester, {
    required Size size,
    required bool isCompact,
    VoidCallback? onSettingsTap,
    Locale? locale,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AppNavbar(
              currentIndex: 0,
              isCompact: isCompact,
              onTap: (_) {},
              onSettingsTap: onSettingsTap,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Android at 1280 px shows the tabs and no window buttons',
    (tester) async {
      await pumpNavbar(tester, size: const Size(1280, 720), isCompact: false);

      for (final label in ['Home', 'Explore', 'Live TV', 'Library']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byType(AppWindowButtons), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Android at 400 px shows search and a profile menu that opens Settings',
    (tester) async {
      var settingsOpened = false;
      await pumpNavbar(
        tester,
        size: const Size(400, 800),
        isCompact: true,
        onSettingsTap: () => settingsOpened = true,
      );

      expect(find.text('Explore'), findsNothing);
      expect(find.byIcon(Icons.search), findsOneWidget);

      await tester.tap(find.byIcon(Icons.person_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Log out'), findsOneWidget);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(settingsOpened, isTrue);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  // REV-253: the search icon has a tooltip in the app's language.
  for (final (locale, l10n) in [
    (const Locale('en'), AppLocalizationsEn()),
    (const Locale('it'), AppLocalizationsIt()),
  ]) {
    testWidgets(
      'search tooltip in ${locale.languageCode}',
      (tester) async {
        await pumpNavbar(
          tester,
          size: const Size(1280, 720),
          isCompact: false,
          locale: locale,
        );

        expect(find.byTooltip(l10n.navSearch), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
}
