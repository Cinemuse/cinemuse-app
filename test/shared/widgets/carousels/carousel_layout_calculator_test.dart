import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/shared/widgets/carousels/carousel_layout_calculator.dart';

void main() {
  group('CarouselLayoutCalculator', () {
    test('calculates exactly 2.3 cards visible on 390px mobile viewport', () {
      const screenWidth = 390.0;
      const padding = EdgeInsets.symmetric(horizontal: 16);
      const spacing = 16.0;
      const visibleCards = 2.3;

      final dimensions = CarouselLayoutCalculator.calculatePosterDimensions(
        screenWidth: screenWidth,
        padding: padding,
        spacing: spacing,
        visibleCards: visibleCards,
      );

      // Expected itemWidth = (390 - 16 - 2 * 16) / 2.3 = 342 / 2.3 ≈ 148.696
      expect(dimensions.itemWidth, closeTo(148.696, 0.001));

      // Verify exact screen boundary visibility:
      // Left padding + 2 full cards + 2 spacing gaps + 0.3 of 3rd card
      final totalOccupiedAtEdge =
          padding.left +
          (2 * dimensions.itemWidth) +
          (2 * spacing) +
          (0.3 * dimensions.itemWidth);

      expect(totalOccupiedAtEdge, closeTo(screenWidth, 0.001));

      // Proportional height check: poster (width / 0.7) + 60px metadata
      final expectedHeight = (dimensions.itemWidth / 0.7) + 60.0;
      expect(dimensions.height, closeTo(expectedHeight, 0.001));
    });

    test(
      'calculates exactly 2.3 cards visible on 360px and 430px viewports',
      () {
        for (final width in [360.0, 393.0, 412.0, 430.0]) {
          const padding = EdgeInsets.symmetric(horizontal: 16);
          const spacing = 16.0;

          final dims = CarouselLayoutCalculator.calculatePosterDimensions(
            screenWidth: width,
            padding: padding,
            spacing: spacing,
          );

          final totalAtEdge =
              padding.left +
              (2 * dims.itemWidth) +
              (2 * spacing) +
              (0.3 * dims.itemWidth);

          expect(
            totalAtEdge,
            closeTo(width, 0.001),
            reason: 'Failed exact 2.3 card boundary for width $width',
          );
        }
      },
    );

    test('reverts to standard desktop sizing when width >= 600', () {
      final dims = CarouselLayoutCalculator.calculatePosterDimensions(
        screenWidth: 1200.0,
      );

      expect(
        dims.itemWidth,
        equals(CarouselLayoutCalculator.defaultPosterWidthDesktop),
      );
      expect(
        dims.height,
        equals(CarouselLayoutCalculator.defaultPosterHeightDesktop),
      );
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
      final totalAtEdge =
          padding.left +
          (1 * dims.itemWidth) +
          (1 * spacing) +
          (0.3 * dims.itemWidth);

      expect(totalAtEdge, closeTo(screenWidth, 0.001));
    });
  });
}
