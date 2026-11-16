import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/core/constants/tmdb_image_helper.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/home/presentation/widgets/hero/hero_slide_content.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:flutter/material.dart';

/// One page of the Home hero: the backdrop, its fades and the title block.
class HeroSlide extends StatelessWidget {
  final MediaItem item;
  final bool isMobile;
  final bool isWidescreen;
  final bool isHeroFocused;
  final double heroHeight;
  final VoidCallback onPlay;
  final VoidCallback onDetails;

  const HeroSlide({
    super.key,
    required this.item,
    required this.isMobile,
    required this.isWidescreen,
    required this.isHeroFocused,
    required this.heroHeight,
    required this.onPlay,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = TmdbImageHelper.backdropUrl(context, item.backdropPath);

    return Stack(
      fit: StackFit.expand,
      children: [
        _HeroBackdrop(imageUrl: imageUrl, heroHeight: heroHeight),
        ..._HeroGradients.build(context, isMobile),
        // Ambient dimming when hero is not focused in widescreen mode
        if (isWidescreen)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: isHeroFocused ? 0.0 : 0.4,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                ),
              ),
            ),
          ),
        Positioned(
          left: AppTheme.getResponsiveHorizontalPadding(context),
          bottom: isMobile ? 36 : 80,
          right: isMobile ? 90 : 180, // Leave room for indicators on the right
          child: HeroSlideContent(
            item: item,
            isMobile: isMobile,
            isWidescreen: isWidescreen,
            isHeroFocused: isHeroFocused,
            onPlay: onPlay,
            onDetails: onDetails,
          ),
        ),
      ],
    );
  }
}

class _HeroBackdrop extends StatelessWidget {
  final String? imageUrl;
  final double heroHeight;

  const _HeroBackdrop({required this.imageUrl, required this.heroHeight});

  @override
  Widget build(BuildContext context) {
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final url = imageUrl;
    if (url == null) return Container(color: surfaceColor);

    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      memCacheHeight: (heroHeight * pixelRatio).round(),
      placeholder: (context, url) => Container(color: surfaceColor),
      errorWidget: (context, url, error) => Container(color: surfaceColor),
    );
  }
}

abstract final class _HeroGradients {
  static List<Widget> build(BuildContext context, bool isMobile) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    return [
      // Left to Right (Primary -> Transparent)
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              bgColor,
              bgColor.withValues(alpha: isMobile ? 0.35 : 0.4),
              Colors.transparent,
            ],
            stops: isMobile ? const [0.0, 0.3, 0.85] : const [0.0, 0.4, 1.0],
          ),
        ),
      ),

      // Bottom to Top (Primary -> Transparent)
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              bgColor,
              bgColor,
              bgColor.withValues(alpha: isMobile ? 0.45 : 0.6),
              Colors.transparent,
            ],
            stops: isMobile
                ? const [0.0, 0.08, 0.35, 1.0]
                : const [0.0, 0.05, 0.3, 1.0],
          ),
        ),
      ),
    ];
  }
}
