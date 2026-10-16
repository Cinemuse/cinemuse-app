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
    final theme = Theme.of(context);

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
              AspectRatio(
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
                            placeholder: (context, url) => Container(
                              color: theme.colorScheme.surfaceContainer,
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: theme.colorScheme.surfaceContainer,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (isFocused || isHovered)
                                  ? theme.focusColor
                                  : AppTheme.surfaceOverlay,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: (isFocused || isHovered)
                                    ? theme.colorScheme.primary
                                    : AppTheme.borderSubtle,
                              ),
                            ),
                            child: Icon(
                              Icons.play_arrow,
                              color: (isFocused || isHovered)
                                  ? theme.colorScheme.primary
                                  : AppTheme.textWhite,
                              size: (isFocused || isHovered) ? 28 : 24,
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
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Text(
                  name,
                  maxLines: 2,
                  textAlign: TextAlign.left,
                  overflow: TextOverflow.ellipsis,
                  style: DesktopTypography.bodySecondary.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isFocused || isHovered
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      child: const SizedBox.shrink(),
    );
  }
}
