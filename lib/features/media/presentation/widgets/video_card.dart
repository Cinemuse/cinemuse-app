import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/card_focus_border.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

class VideoCard extends StatelessWidget {
  final String youtubeKey;
  final String name;
  final VoidCallback onTap;

  const VideoCard({
    super.key,
    required this.youtubeKey,
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DpadFocusable(
      onTap: onTap,
      scale: 1.04,
      borderRadius: AppTheme.radiusLg,
      showFocusRing: false,
      builder: (context, isFocused, isHovered, child) {
        return SizedBox(
          width: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _VideoThumbnail(
                youtubeKey: youtubeKey,
                isFocused: isFocused,
                isLit: isFocused || isHovered,
              ),
              const SizedBox(height: 12),
              Flexible(
                child: _VideoName(name: name, isLit: isFocused || isHovered),
              ),
            ],
          ),
        );
      },
      child: const SizedBox.shrink(),
    );
  }
}

/// [VideoCard] as a line of a list going down, for a phone: the picture on
/// the left, the name beside it.
class VideoListTile extends StatelessWidget {
  final String youtubeKey;
  final String name;
  final VoidCallback onTap;

  const VideoListTile({
    super.key,
    required this.youtubeKey,
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DpadFocusable(
      onTap: onTap,
      borderRadius: AppTheme.radiusLg,
      showFocusRing: false,
      builder: (context, isFocused, isHovered, child) {
        return Row(
          children: [
            SizedBox(
              width: 140,
              child: _VideoThumbnail(
                youtubeKey: youtubeKey,
                isFocused: isFocused,
                isLit: isFocused || isHovered,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _VideoName(name: name, isLit: isFocused || isHovered),
            ),
          ],
        );
      },
      child: const SizedBox.shrink(),
    );
  }
}

class _VideoThumbnail extends StatelessWidget {
  final String youtubeKey;
  final bool isFocused;
  final bool isLit;

  const _VideoThumbnail({
    required this.youtubeKey,
    required this.isFocused,
    required this.isLit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: AppTheme.radiusLg,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CachedNetworkImage(
                  imageUrl:
                      'https://img.youtube.com/vi/$youtubeKey/mqdefault.jpg',
                  memCacheWidth: 400,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: theme.colorScheme.surfaceContainer),
                  errorWidget: (context, url, error) =>
                      Container(color: theme.colorScheme.surfaceContainer),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isLit ? theme.focusColor : AppTheme.surfaceOverlay,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isLit
                          ? theme.colorScheme.primary
                          : AppTheme.borderSubtle,
                    ),
                  ),
                  child: Icon(
                    Icons.play_arrow,
                    color: isLit
                        ? theme.colorScheme.primary
                        : AppTheme.textWhite,
                    size: isLit ? 28 : 24,
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: CardFocusBorder(
              isFocused: isFocused,
              borderRadius: AppTheme.radiusLg,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoName extends StatelessWidget {
  final String name;
  final bool isLit;

  const _VideoName({required this.name, required this.isLit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      name,
      maxLines: 2,
      textAlign: TextAlign.left,
      overflow: TextOverflow.ellipsis,
      style: DesktopTypography.bodySecondary.copyWith(
        fontWeight: FontWeight.bold,
        color: isLit
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withValues(alpha: 0.9),
      ),
    );
  }
}
