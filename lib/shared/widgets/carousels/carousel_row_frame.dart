import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'package:cinemuse_app/shared/widgets/bento_box.dart';
import 'package:cinemuse_app/shared/widgets/carousels/carousel_header.dart';
import 'package:flutter/material.dart';

enum CarouselTheme {
  homeRow, // Title + chevron right (no box)
  profileRow, // Icon + Title + chevron right inside a container with surface color
  bentoBox, // BentoBox with title and icon
  plain, // No header
}

/// What goes around a carousel row's list for each [CarouselTheme]: the
/// title line with the scroll [arrows], and the profile / Bento box.
class CarouselRowFrame extends StatelessWidget {
  final CarouselTheme theme;
  final String? title;
  final IconData? icon;
  final Widget? headerAction;
  final VoidCallback? onHeaderTap;

  /// The row's own list padding ([EdgeInsets.zero] = the theme's default).
  final EdgeInsets padding;
  final Widget arrows;

  /// Builds the list with the padding this theme gives it.
  final Widget Function(EdgeInsets padding) buildList;

  const CarouselRowFrame({
    super.key,
    required this.theme,
    required this.title,
    required this.icon,
    required this.headerAction,
    required this.onHeaderTap,
    required this.padding,
    required this.arrows,
    required this.buildList,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Breakpoints.isCompact(context);
    switch (theme) {
      case CarouselTheme.bentoBox:
        return BentoBox(
          title: title ?? '',
          icon: icon,
          action: headerAction != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [headerAction!, const SizedBox(width: 8), arrows],
                )
              : arrows,
          child: buildList(padding),
        );
      case CarouselTheme.profileRow:
        final horizontalPadding = isMobile ? 16.0 : 24.0;
        final listPadding = padding != EdgeInsets.zero
            ? padding
            : EdgeInsets.symmetric(horizontal: horizontalPadding);

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.only(top: 24, bottom: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: _TitleLine(frame: this, isSmall: true),
                ),
                const SizedBox(height: 16),
                buildList(listPadding),
              ],
            ),
          ),
        );
      case CarouselTheme.homeRow:
        final horizontalPadding = padding.left > 0
            ? padding.left
            : (isMobile ? 16.0 : 24.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                isMobile ? 4 : 8,
                horizontalPadding,
                isMobile ? 8 : 16,
              ),
              child: _TitleLine(frame: this, isSmall: false),
            ),
            buildList(padding),
          ],
        );
      case CarouselTheme.plain:
        return buildList(padding);
    }
  }
}

/// The row title (profile rows: with their icon) and the scroll arrows.
class _TitleLine extends StatelessWidget {
  final CarouselRowFrame frame;
  final bool isSmall;

  const _TitleLine({required this.frame, required this.isSmall});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: CarouselHeader(
              title: frame.title ?? '',
              icon: isSmall ? frame.icon : null,
              isSmall: isSmall,
              onTap: frame.onHeaderTap,
            ),
          ),
        ),
        frame.arrows,
      ],
    );
  }
}
