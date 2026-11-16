import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/services/system/app_full_screen.dart';
import 'package:cinemuse_app/features/navigation/presentation/navbar.dart';
import 'package:cinemuse_app/features/navigation/presentation/window_buttons.dart';
import 'package:cinemuse_app/features/updates/application/update_service.dart';
import 'package:cinemuse_app/features/updates/domain/update_state.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/l10n/app_localizations_it.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

/// A new version is out when [latestVersion] is set.
class _FixedUpdateNotifier extends UpdateNotifier {
  final String? latestVersion;

  _FixedUpdateNotifier(this.latestVersion);

  @override
  UpdateState build() => UpdateState(
    status: latestVersion == null
        ? UpdateStatus.upToDate
        : UpdateStatus.available,
    latestVersion: latestVersion,
  );
}

// REV-51: the navbar layout follows the shell's width rule on every
// platform; only the window buttons depend on the platform.
void main() {
  Future<void> pumpNavbar(
    WidgetTester tester, {
    required Size size,
    required bool isCompact,
    VoidCallback? onSettingsTap,
    Locale? locale,
    bool hasUpdate = false,
    bool isFullScreen = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [
          updatesShownProvider.overrideWithValue(true),
          updateProvider.overrideWith(
            () => _FixedUpdateNotifier(hasUpdate ? 'v1.9.3' : null),
          ),
          appFullScreenProvider.overrideWith(
            () => AppFullScreenNotifier(startsOn: isFullScreen),
          ),
        ],
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
    'the open page: 25% purple, a 50% purple border, bold white text',
    (tester) async {
      await pumpNavbar(tester, size: const Size(1280, 720), isCompact: false);

      final tab = tester.widget<AnimatedContainer>(
        find.ancestor(
          of: find.text('Home'),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final decoration = tab.decoration! as BoxDecoration;
      expect(decoration.color, AppTheme.accent.withValues(alpha: 0.25));
      expect(decoration.color, AppTheme.accentSelectedBg);
      expect(
        (decoration.border! as Border).top.color,
        AppTheme.accentSelectedBorder,
      );
      expect(AppTheme.accentSelectedBorder.a, closeTo(0.5, 0.001));
      expect(
        tester.widget<Text>(find.text('Home')).style?.fontWeight,
        FontWeight.bold,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Windows: the window buttons in a window, none in full screen',
    (tester) async {
      const channel = MethodChannel('window_manager');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'isMaximized' ? false : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await pumpNavbar(tester, size: const Size(1280, 720), isCompact: false);
      expect(find.byType(AppWindowButtons), findsOneWidget);

      // A fresh app: the full-screen state is set when it starts.
      await tester.pumpWidget(const SizedBox());
      await pumpNavbar(
        tester,
        size: const Size(1280, 720),
        isCompact: false,
        isFullScreen: true,
      );
      expect(find.byType(AppWindowButtons), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

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
    'Android at 400 px shows search and a gear that opens Settings',
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

      expect(find.byIcon(Icons.person_rounded), findsNothing);

      await tester.tap(find.byTooltip('Settings'));
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

  bool showsDot(WidgetTester tester) => tester
      .widget<Badge>(
        find.ancestor(
          of: find.byIcon(Icons.settings_outlined),
          matching: find.byType(Badge),
        ),
      )
      .isLabelVisible;

  for (final (name, size, isCompact) in [
    ('phone', const Size(400, 800), true),
    ('TV', const Size(1280, 720), false),
  ]) {
    for (final hasUpdate in [false, true]) {
      testWidgets('$name: a dot on the gear only when a new version is out '
          '(new version: $hasUpdate)', (tester) async {
        await pumpNavbar(
          tester,
          size: size,
          isCompact: isCompact,
          hasUpdate: hasUpdate,
        );
        expect(showsDot(tester), hasUpdate);
      });
    }
  }
}
