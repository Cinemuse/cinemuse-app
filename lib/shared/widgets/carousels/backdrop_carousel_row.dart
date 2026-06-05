import 'package:flutter/material.dart';
import 'package:cinemuse_app/shared/widgets/carousels/generic_carousel_row.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class BackdropCarouselRow extends StatelessWidget {
  final List<Widget> items;
  final String? title;
  final IconData? icon;
  final CarouselTheme theme;
  final WidgetBuilder? emptyBuilder;
  final double height;
  final double itemWidth;
  final EdgeInsets padding;
  final ScrollController? controller;
  final double spacing;

  const BackdropCarouselRow({
    super.key,
    required this.items,
    this.title,
    this.icon,
    this.theme = CarouselTheme.plain,
    this.emptyBuilder,
    this.height = 240, // Standard height for backdrop carousels
    this.itemWidth = 320,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
    this.controller,
    this.spacing = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return GenericCarouselRow(
      title: title,
      icon: icon,
      theme: theme,
      controller: controller,
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
      separatorBuilder: (c, i) => SizedBox(width: spacing),
      itemBuilder: (context, index) {
        return SizedBox(width: itemWidth, child: items[index]);
      },
    );
  }
}
