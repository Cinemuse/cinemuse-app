import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/shared/widgets/carousels/carousel_layout_calculator.dart';
import 'package:cinemuse_app/shared/widgets/carousels/poster_carousel_row.dart';
import 'package:cinemuse_app/shared/widgets/carousels/generic_carousel_row.dart';

void main() {
  group('CarouselLayoutCalculator', () {
    test('calculates exactly 3.2 cards visible on 390px mobile viewport', () {
      const screenWidth = 390.0;
      const padding = EdgeInsets.symmetric(horizontal: 16);
      const spacing = 16.0;
      const visibleCards = 3.2;

      final dimensions = CarouselLayoutCalculator.calculatePosterDimensions(
        screenWidth: screenWidth,
        padding: padding,
        spacing: spacing,
        visibleCards: visibleCards,
      );

      // Expected itemWidth = (390 - 16 - 3 * 16) / 3.2 = 326 / 3.2 = 101.875
      expect(dimensions.itemWidth, closeTo(101.875, 0.001));

      // Verify exact screen boundary visibility:
      // Left padding + 3 full cards + 3 spacing gaps + 0.2 of 4th card
      final totalOccupiedAtEdge = padding.left +
          (3 * dimensions.itemWidth) +
          (3 * spacing) +
          (0.2 * dimensions.itemWidth);

      expect(totalOccupiedAtEdge, closeTo(screenWidth, 0.001));

      // Proportional height check: poster (width / 0.7) + 60px metadata
      final expectedHeight = (dimensions.itemWidth / 0.7) + 60.0;
      expect(dimensions.height, closeTo(expectedHeight, 0.001));
    });

    test('calculates exactly 3.2 cards visible on 360px and 430px viewports', () {
      for (final width in [360.0, 393.0, 412.0, 430.0]) {
        const padding = EdgeInsets.symmetric(horizontal: 16);
        const spacing = 16.0;

        final dims = CarouselLayoutCalculator.calculatePosterDimensions(
          screenWidth: width,
          padding: padding,
          spacing: spacing,
        );

        final totalAtEdge = padding.left +
            (3 * dims.itemWidth) +
            (3 * spacing) +
            (0.2 * dims.itemWidth);

        expect(totalAtEdge, closeTo(width, 0.001),
            reason: 'Failed exact 3.2 card boundary for width $width');
      }
    });

    test('reverts to standard desktop sizing when width >= 600', () {
      final dims = CarouselLayoutCalculator.calculatePosterDimensions(
        screenWidth: 1200.0,
      );

      expect(dims.itemWidth, equals(CarouselLayoutCalculator.defaultPosterWidthDesktop));
      expect(dims.height, equals(CarouselLayoutCalculator.defaultPosterHeightDesktop));
    });

    test('calculates responsive backdrop dimensions for mobile', () {
      const screenWidth = 390.0;
      const padding = EdgeInsets.symmetric(horizontal: 16);
      const spacing = 16.0;
      const visibleCards = 1.3;

      final dims = CarouselLayoutCalculator.calculateBackdropDimensions(
        screenWidth: screenWidth,
        padding: padding,
        spacing: spacing,
        visibleCards: visibleCards,
      );

      // (390 - 16 - 1 * 16) / 1.3 = 358 / 1.3 ≈ 275.38
      final totalAtEdge = padding.left +
          (1 * dims.itemWidth) +
          (1 * spacing) +
          (0.3 * dims.itemWidth);

      expect(totalAtEdge, closeTo(screenWidth, 0.001));
    });
  });

  group('PosterCarouselRow Widget', () {
    testWidgets('renders items with responsive width on mobile viewport',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final items = List.generate(
        10,
        (i) => Container(
          key: ValueKey('item_$i'),
          color: Colors.blue,
          child: Text('Item $i'),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PosterCarouselRow(
              items: items,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find first item's sized box
      final firstItemFinder = find.byKey(const ValueKey('item_0'));
      expect(firstItemFinder, findsOneWidget);

      final size = tester.getSize(firstItemFinder);
      // Expected width is (390 - 16 - 48) / 3.2 = 101.875
      expect(size.width, closeTo(101.875, 0.5));
    });

    testWidgets('renders items with default 200px width on desktop viewport',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final items = List.generate(
        5,
        (i) => Container(
          key: ValueKey('item_$i'),
          color: Colors.blue,
          child: Text('Item $i'),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PosterCarouselRow(
              items: items,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final firstItemFinder = find.byKey(const ValueKey('item_0'));
      expect(firstItemFinder, findsOneWidget);

      final size = tester.getSize(firstItemFinder);
      expect(size.width, equals(200.0));
    });

    testWidgets('uses 24px padding for profileRow theme on desktop viewport',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final items = List.generate(
        5,
        (i) => Container(
          key: ValueKey('profile_item_$i'),
          color: Colors.blue,
          child: Text('Item $i'),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PosterCarouselRow(
              title: 'RECENT MOVIES',
              theme: CarouselTheme.profileRow,
              items: items,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final firstItemFinder = find.byKey(const ValueKey('profile_item_0'));
      expect(firstItemFinder, findsOneWidget);

      final topLeft = tester.getTopLeft(firstItemFinder);
      // On desktop (1200 width), getResponsiveHorizontalPadding would be 60.0 (+1px border = 61.0).
      // With the fix, profileRow list padding starts at 24.0 (+ 1.0 border = 25.0), aligning with the card's header.
      expect(topLeft.dx, equals(25.0));
    });

    testWidgets('uses 16px padding for profileRow theme on mobile viewport',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final items = List.generate(
        5,
        (i) => Container(
          key: ValueKey('mobile_profile_item_$i'),
          color: Colors.blue,
          child: Text('Item $i'),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PosterCarouselRow(
              title: 'RECENT MOVIES',
              theme: CarouselTheme.profileRow,
              items: items,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final firstItemFinder =
          find.byKey(const ValueKey('mobile_profile_item_0'));
      expect(firstItemFinder, findsOneWidget);

      final topLeft = tester.getTopLeft(firstItemFinder);
      // 1.0 container border + 16.0 mobile padding = 17.0
      expect(topLeft.dx, equals(17.0));
    });
  });
}
