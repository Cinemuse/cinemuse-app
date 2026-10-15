import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/features/navigation/presentation/navbar.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

import '../../helpers/focus_helpers.dart';

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
    'Pressing arrowDown in AppNavbar runs the current tab content action',
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

  testWidgets('the focused tab shows its outline and nothing moves '
      '(REV-249, REV-250)', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late WidgetRef testRef;
    final opened = <int>[];
    var searchOpened = false;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            testRef = ref;
            return buildTestableNavbar(
              ref: ref,
              currentIndex: 0,
              onTap: opened.add,
              onSearchTap: () => searchOpened = true,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final items = [
      find.text('Home'),
      find.text('Explore'),
      find.text('Live TV'),
      find.text('Library'),
      find.byIcon(Icons.search),
      find.byIcon(Icons.person_rounded),
    ];
    final tabs = items.take(4).toList();
    List<Rect> rects() => [for (final f in items) tester.getRect(f)];
    // The outline is the look being checked: the pill's foreground ring.
    bool hasOutline(Finder tab) =>
        tester
            .widget<AnimatedContainer>(
              find.ancestor(of: tab, matching: find.byType(AnimatedContainer)),
            )
            .foregroundDecoration !=
        null;
    // Bold labels made the bar move, but the test font is as wide in bold,
    // so the weight is checked too.
    FontWeight? weight(Finder tab) =>
        tester.widget<Text>(tab).style?.fontWeight;
    final weights = [for (final t in tabs) weight(t)];
    final before = rects();

    // Up from a page focuses the active tab.
    testRef.read(topNavbarFocusActionProvider)!();
    await tester.pumpAndSettle();
    expect(isFocused(tabs[0]), isTrue);
    expect(hasOutline(tabs[0]), isTrue);

    // Left on the first tab does nothing.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(isFocused(tabs[0]), isTrue);

    for (var i = 1; i < items.length; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(isFocused(items[i]), isTrue, reason: 'item $i');
      for (var t = 0; t < tabs.length; t++) {
        expect(hasOutline(tabs[t]), t == i, reason: 'outline on tab $t');
      }
      expect(rects(), before, reason: 'the bar moved at item $i');
      expect([for (final t in tabs) weight(t)], weights, reason: 'item $i');
    }

    // Right on the last item (profile) does nothing.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(isFocused(items[5]), isTrue);

    // Enter opens the profile menu, the search and a tab.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Log out'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await tabTo(tester, items[4]);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(searchOpened, isTrue);

    await tabTo(tester, tabs[2]);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(opened, [2]);
  });

  testWidgets('Tab stops once on each navbar button (REV-57)', (tester) async {
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
            return buildTestableNavbar(ref: ref);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    testRef.read(topNavbarFocusActionProvider)!();
    await tester.pumpAndSettle();

    final stops = <String?>[FocusManager.instance.primaryFocus?.debugLabel];
    for (var i = 0; i < 5; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      stops.add(FocusManager.instance.primaryFocus?.debugLabel);
    }

    expect(stops, [for (var i = 0; i < 6; i++) 'NavbarPill_$i']);
  });
}
