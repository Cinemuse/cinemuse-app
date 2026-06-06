import 'package:flutter/material.dart';
import 'package:cinemuse_app/shared/widgets/carousels/generic_carousel_row.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class PosterCarouselRow extends StatelessWidget {
  final List<Widget> items;
  final String? title;
  final IconData? icon;
  final CarouselTheme theme;
  final WidgetBuilder? emptyBuilder;
  final double height;
  final double itemWidth;
  final EdgeInsets padding;
  final ScrollController? controller;
  final VoidCallback? onHeaderTap;

  const PosterCarouselRow({
    super.key,
    required this.items,
    this.title,
    this.icon,
    this.theme = CarouselTheme.plain,
    this.emptyBuilder,
    this.height = 356, // Standard height for poster carousels
    this.itemWidth = 200,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
    this.controller,
    this.onHeaderTap,
  });

  @override
  Widget build(BuildContext context) {
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
      height: height,
      itemCount: items.length,
      padding: padding,
      separatorBuilder: (c, i) => const SizedBox(width: 16),
      itemBuilder: (context, index) {
        return SizedBox(width: itemWidth, child: items[index]);
      },
    );
  }
}
