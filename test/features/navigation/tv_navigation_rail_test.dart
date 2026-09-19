import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/features/navigation/tv_navigation_rail.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

void main() {
  Widget buildTestableWidget({
    int currentIndex = 0,
    ValueChanged<int>? onDestinationSelected,
    VoidCallback? onSearchTap,
    VoidCallback? onSettingsTap,
    VoidCallback? onExitRight,
    GlobalKey<TvNavigationRailState>? railKey,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TvNavigationRail(
          key: railKey,
          currentIndex: currentIndex,
          onDestinationSelected: onDestinationSelected ?? (_) {},
          onSearchTap: onSearchTap ?? () {},
          onSettingsTap: onSettingsTap ?? () {},
          onExitRight: onExitRight,
        ),
      ),
    );
  }

  testWidgets('TvNavigationRail renders icons and collapsed initial state', (tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.explore_outlined), findsOneWidget);
    expect(find.byIcon(Icons.live_tv_outlined), findsOneWidget);
    expect(find.byIcon(Icons.video_library_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer).first,
    );
    expect(container.constraints?.maxWidth, equals(76.0));
  });

  testWidgets('TvNavigationRail expands when an item gains focus', (tester) async {
    final railKey = GlobalKey<TvNavigationRailState>();
    await tester.pumpWidget(buildTestableWidget(railKey: railKey));
    await tester.pumpAndSettle();

    expect(railKey.currentState?.isExpanded, isFalse);

    // Programmatically focus the active item
    railKey.currentState?.focusActiveItem();
    await tester.pumpAndSettle();

    expect(railKey.currentState?.isExpanded, isTrue);

    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer).first,
    );
    expect(container.constraints?.maxWidth, equals(220.0));
  });

  testWidgets('TvNavigationRail triggers destination selection on tap', (tester) async {
    int? selectedIndex;
    await tester.pumpWidget(
      buildTestableWidget(
        currentIndex: 0,
        onDestinationSelected: (index) => selectedIndex = index,
      ),
    );
    await tester.pumpAndSettle();

    // Tap on Explore (icon `Icons.explore_outlined`)
    await tester.tap(find.byIcon(Icons.explore_outlined));
    await tester.pumpAndSettle();

    expect(selectedIndex, equals(1));
  });

  testWidgets('TvNavigationRail calls onSearchTap and onSettingsTap', (tester) async {
    bool searchTapped = false;
    bool settingsTapped = false;

    await tester.pumpWidget(
      buildTestableWidget(
        onSearchTap: () => searchTapped = true,
        onSettingsTap: () => settingsTapped = true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();
    expect(searchTapped, isTrue);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(settingsTapped, isTrue);
  });

  testWidgets('TvNavigationRail triggers onExitRight on arrow right key', (tester) async {
    bool exitedRight = false;
    final railKey = GlobalKey<TvNavigationRailState>();

    await tester.pumpWidget(
      buildTestableWidget(
        railKey: railKey,
        onExitRight: () => exitedRight = true,
      ),
    );
    await tester.pumpAndSettle();

    railKey.currentState?.focusActiveItem();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(exitedRight, isTrue);
  });

  testWidgets('TvNavigationRail disallows going left and stays focused on the sidebar', (tester) async {
    final railKey = GlobalKey<TvNavigationRailState>();

    await tester.pumpWidget(
      buildTestableWidget(railKey: railKey),
    );
    await tester.pumpAndSettle();

    railKey.currentState?.focusActiveItem();
    await tester.pumpAndSettle();

    expect(railKey.currentState?.isFocused, isTrue);

    // Send single arrowLeft: should be handled and stay on rail
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(railKey.currentState?.isFocused, isTrue);

    // Send repeated arrowLeft (long press): should stay on rail
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    for (int i = 0; i < 5; i++) {
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(railKey.currentState?.isFocused, isTrue);
  });
}
