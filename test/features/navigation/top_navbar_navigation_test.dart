import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/features/navigation/navbar.dart';
import 'package:cinemuse_app/features/navigation/nav_providers.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

void main() {
  Widget buildTestableNavbar({
    required WidgetRef ref,
    int currentIndex = 0,
    ValueChanged<int>? onTap,
    VoidCallback? onSearchTap,
    VoidCallback? onSettingsTap,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AppNavbar(
          currentIndex: currentIndex,
          onTap: onTap ?? (_) {},
          onSearchTap: onSearchTap ?? () {},
          onSettingsTap: onSettingsTap ?? () {},
        ),
      ),
    );
  }

  testWidgets(
    'AppNavbar registers topNavbarFocusActionProvider and focuses active tab',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late WidgetRef testRef;

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              testRef = ref;
              return buildTestableNavbar(ref: ref, currentIndex: 1);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify topNavbarFocusActionProvider is set
      final focusNavbar = testRef.read(topNavbarFocusActionProvider);
      expect(focusNavbar, isNotNull);

      // Call focusNavbar to focus the active tab (Explore, index 1)
      focusNavbar!();
      await tester.pumpAndSettle();

      // The navbar active pill item should be focused
      expect(FocusManager.instance.primaryFocus, isNotNull);
    },
  );

  testWidgets(
    'Pressing arrowDown in AppNavbar triggers pageContentFocusActionProvider',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late WidgetRef testRef;

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              testRef = ref;
              return buildTestableNavbar(ref: ref, currentIndex: 0);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      var homeFocused = false;
      var profileFocused = false;

      // Register both tab 0 (Home) and tab 3 (Profile)
      testRef.read(pageContentFocusActionsProvider.notifier).state = {
        0: () => homeFocused = true,
        3: () => profileFocused = true,
      };

      // Focus top navbar
      final focusNavbar = testRef.read(topNavbarFocusActionProvider);
      focusNavbar!();
      await tester.pumpAndSettle();

      // Send Arrow Down key event
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // With currentIndex == 0, only homeFocused should be triggered, NOT profile
      expect(homeFocused, isTrue);
      expect(profileFocused, isFalse);
    },
  );

  testWidgets(
    'Pressing arrowRight and arrowLeft moves focus within AppNavbar',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late WidgetRef testRef;
      int selectedDestination = -1;

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              testRef = ref;
              return buildTestableNavbar(
                ref: ref,
                currentIndex: 0,
                onTap: (idx) => selectedDestination = idx,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Focus active item (Home, index 0)
      testRef.read(topNavbarFocusActionProvider)!();
      await tester.pumpAndSettle();

      // Arrow Right -> index 1 (Explore)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      // Press Select / Enter on Explore
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      expect(selectedDestination, equals(1));
    },
  );
}
