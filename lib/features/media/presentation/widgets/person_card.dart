import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/core/constants/tmdb_image_helper.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/card_focus_border.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:flutter/material.dart';

class PersonCard extends StatelessWidget {
  final String? profilePath;
  final String name;
  final String character;
  final VoidCallback onTap;

  const PersonCard({
    super.key,
    this.profilePath,
    required this.name,
    required this.character,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tooltipText = character.isNotEmpty ? '$name\n$character' : name;

    return Tooltip(
      message: tooltipText,
      waitDuration: const Duration(milliseconds: 600),
      child: DpadFocusable(
        onTap: onTap,
        scale: 1.05,
        borderRadius: AppTheme.radiusLg,
        showFocusRing: false,
        builder: (context, isFocused, isHovered, child) {
          return SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 2 / 3,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: AppTheme.radiusLg,
                        child: CachedNetworkImage(
                          imageUrl: profilePath != null
                              ? TmdbImageHelper.profileUrl(
                                  context,
                                  profilePath,
                                )!
                              : '',
                          fit: BoxFit.cover,
                          memCacheWidth: 270,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (context, url) => Container(
                            color: theme.colorScheme.surfaceContainer,
                          ),
                          errorWidget: (context, url, error) => Image.asset(
                            'assets/cast_placeholder.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: CardFocusBorder(
                          isFocused: isFocused,
                          isHovered: isHovered,
                          borderRadius: AppTheme.radiusLg,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Name
                Text(
                  name,
                  style: DesktopTypography.bodySecondary.copyWith(
                    color: isFocused || isHovered
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.9),
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Character
                Text(
                  character,
                  style: DesktopTypography.captionMeta.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
        child: const SizedBox.shrink(),
      ),
    );
  }
}
