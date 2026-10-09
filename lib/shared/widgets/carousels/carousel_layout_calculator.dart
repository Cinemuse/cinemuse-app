import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';

/// Holds the computed layout dimensions for carousel cards.
class CarouselDimensions {
  final double itemWidth;
  final double height;

  const CarouselDimensions({required this.itemWidth, required this.height});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CarouselDimensions &&
          runtimeType == other.runtimeType &&
          itemWidth == other.itemWidth &&
          height == other.height;

  @override
  int get hashCode => Object.hash(itemWidth, height);

  @override
  String toString() =>
      'CarouselDimensions(itemWidth: $itemWidth, height: $height)';
}

/// Helper class to compute responsive dimensions for horizontal card carousels.
///
/// Ensures exact card visibility on mobile screens (e.g. 3.2 cards visible).
class CarouselLayoutCalculator {
  const CarouselLayoutCalculator._();

  /// Mobile breakpoint consistent with Cinemuse theme conventions.
  static const double mobileBreakpoint = 600.0;

  /// Default desktop dimensions for poster carousels.
  static const double defaultPosterWidthDesktop = 200.0;
  static const double defaultPosterHeightDesktop = 356.0;

  /// Default desktop dimensions for backdrop carousels.
  static const double defaultBackdropWidthDesktop = 320.0;
  static const double defaultBackdropHeightDesktop = 240.0;

  /// Standard spacing between carousel cards.
  static const double defaultSpacing = 16.0;

  /// Number of cards visible on mobile for poster carousels.
  static const double defaultPosterMobileVisibleCards = 2.3;

  /// Number of cards visible on mobile for backdrop carousels.
  static const double defaultBackdropMobileVisibleCards = 1.3;

  /// Calculates responsive dimensions for poster cards (aspect ratio ~0.7).
  ///
  /// On mobile (< 600px), computes the item width so that exactly [visibleCards]
  /// are visible on initial scroll position, and scales the carousel height
  /// proportionally to preserve the poster aspect ratio without vertical stretching.
  static CarouselDimensions calculatePosterDimensions({
    required double screenWidth,
    EdgeInsets? padding,
    double spacing = defaultSpacing,
    double visibleCards = defaultPosterMobileVisibleCards,
    double? customDesktopWidth,
    double? customDesktopHeight,
  }) {
    final isMobile = screenWidth < mobileBreakpoint;
    if (!isMobile) {
      return CarouselDimensions(
        itemWidth: customDesktopWidth ?? defaultPosterWidthDesktop,
        height: customDesktopHeight ?? defaultPosterHeightDesktop,
      );
    }

    final effectivePadding =
        padding ?? const EdgeInsets.symmetric(horizontal: 16);
    final gapCount = visibleCards.floor();
    final availableWidth =
        screenWidth - effectivePadding.left - (gapCount * spacing);
    final itemWidth = (availableWidth / visibleCards).clamp(60.0, 300.0);

    // Poster image aspect ratio is 0.7:
    // Poster image height = itemWidth / 0.7
    // Metadata block: title (~20px) + spacing (8px) + rating/year (~16px) + scrollbar padding (16px) = ~60px
    const metadataHeight = 60.0;
    final totalHeight = (itemWidth / 0.7) + metadataHeight;

    return CarouselDimensions(itemWidth: itemWidth, height: totalHeight);
  }

  /// Calculates responsive dimensions using a [BuildContext].
  static CarouselDimensions getPosterDimensions(
    BuildContext context, {
    EdgeInsets? padding,
    double spacing = defaultSpacing,
    double visibleCards = defaultPosterMobileVisibleCards,
    double? customDesktopWidth,
    double? customDesktopHeight,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final effectivePadding =
        padding ??
        EdgeInsets.symmetric(
          horizontal: AppTheme.getResponsiveHorizontalPadding(context),
        );

    return calculatePosterDimensions(
      screenWidth: screenWidth,
      padding: effectivePadding,
      spacing: spacing,
      visibleCards: visibleCards,
      customDesktopWidth: customDesktopWidth,
      customDesktopHeight: customDesktopHeight,
    );
  }

  /// Calculates responsive dimensions for backdrop cards (aspect ratio 16:9).
  static CarouselDimensions calculateBackdropDimensions({
    required double screenWidth,
    EdgeInsets? padding,
    double spacing = defaultSpacing,
    double visibleCards = defaultBackdropMobileVisibleCards,
    double? customDesktopWidth,
    double? customDesktopHeight,
  }) {
    final isMobile = screenWidth < mobileBreakpoint;
    if (!isMobile) {
      return CarouselDimensions(
        itemWidth: customDesktopWidth ?? defaultBackdropWidthDesktop,
        height: customDesktopHeight ?? defaultBackdropHeightDesktop,
      );
    }

    final effectivePadding =
        padding ?? const EdgeInsets.symmetric(horizontal: 16);
    final gapCount = visibleCards.floor();
    final availableWidth =
        screenWidth - effectivePadding.left - (gapCount * spacing);
    final itemWidth = (availableWidth / visibleCards).clamp(120.0, 500.0);

    // 16:9 aspect ratio for backdrop thumbnail + metadata
    const metadataHeight = 60.0;
    final totalHeight = (itemWidth * (9 / 16)) + metadataHeight;

    return CarouselDimensions(itemWidth: itemWidth, height: totalHeight);
  }

  /// Calculates responsive backdrop dimensions using a [BuildContext].
  static CarouselDimensions getBackdropDimensions(
    BuildContext context, {
    EdgeInsets? padding,
    double spacing = defaultSpacing,
    double visibleCards = defaultBackdropMobileVisibleCards,
    double? customDesktopWidth,
    double? customDesktopHeight,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final effectivePadding =
        padding ??
        EdgeInsets.symmetric(
          horizontal: AppTheme.getResponsiveHorizontalPadding(context),
        );

    return calculateBackdropDimensions(
      screenWidth: screenWidth,
      padding: effectivePadding,
      spacing: spacing,
      visibleCards: visibleCards,
      customDesktopWidth: customDesktopWidth,
      customDesktopHeight: customDesktopHeight,
    );
  }
}
