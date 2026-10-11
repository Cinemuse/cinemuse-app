import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/carousels/generic_carousel_row.dart';
import 'package:cinemuse_app/shared/widgets/carousels/carousel_layout_calculator.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class BackdropCarouselRow extends StatelessWidget {
  final List<Widget> items;
  final String? title;
  final IconData? icon;
  final CarouselTheme theme;
  final WidgetBuilder? emptyBuilder;
  final double? height;
  final double? itemWidth;
  final EdgeInsets? padding;
  final ScrollController? controller;
  final double spacing;
  final VoidCallback? onHeaderTap;
  final double visibleCards;

  const BackdropCarouselRow({
    super.key,
    required this.items,
    this.title,
    this.icon,
    this.theme = CarouselTheme.plain,
    this.emptyBuilder,
    this.height,
    this.itemWidth,
    this.padding,
    this.controller,
    this.spacing = 16.0,
    this.onHeaderTap,
    this.visibleCards =
        CarouselLayoutCalculator.defaultBackdropMobileVisibleCards,
  });

  static EdgeInsets defaultPaddingForTheme(
    BuildContext context,
    CarouselTheme theme,
  ) {
    final isMobile = Breakpoints.isCompact(context);
    switch (theme) {
      case CarouselTheme.profileRow:
        return EdgeInsets.symmetric(horizontal: isMobile ? 16.0 : 24.0);
      case CarouselTheme.bentoBox:
        return EdgeInsets.zero;
      case CarouselTheme.homeRow:
      case CarouselTheme.plain:
        return EdgeInsets.symmetric(
          horizontal: AppTheme.getResponsiveHorizontalPadding(context),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ?? defaultPaddingForTheme(context, theme);

    final dimensions = CarouselLayoutCalculator.getBackdropDimensions(
      context,
      padding: effectivePadding,
      spacing: spacing,
      visibleCards: visibleCards,
      customDesktopWidth: itemWidth,
      customDesktopHeight: height,
    );

    final effectiveItemWidth = itemWidth ?? dimensions.itemWidth;
    final effectiveHeight = height ?? dimensions.height;

    return GenericCarouselRow(
      title: title,
      icon: icon,
      theme: theme,
      controller: controller,
      onHeaderTap: onHeaderTap,
      emptyBuilder:
          emptyBuilder ??
          (context) => SizedBox(
            height: 100,
            child: Center(
              child: Text(
                AppLocalizations.of(context)!.commonNoContent,
                style: const TextStyle(color: Colors.white54),
              ),
            ),
          ),
      height: effectiveHeight,
      itemCount: items.length,
      padding: effectivePadding,
      separatorBuilder: (c, i) => SizedBox(width: spacing),
      itemBuilder: (context, index) {
        return SizedBox(width: effectiveItemWidth, child: items[index]);
      },
    );
  }
}
