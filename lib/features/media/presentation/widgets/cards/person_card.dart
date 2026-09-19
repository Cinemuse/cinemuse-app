import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/core/constants/tmdb_image_helper.dart';

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
    return DpadFocusable(
      onTap: onTap,
      scale: 1.05,
      borderRadius: BorderRadius.circular(16),
      builder: (context, isFocused, isHovered, child) {
        return SizedBox(
          width: 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Photo
              AspectRatio(
                aspectRatio: 2 / 3,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isFocused ? Colors.white : Colors.transparent,
                      width: 2.0,
                    ),
                    boxShadow:
                        isFocused ? AppTheme.shadowCard : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CachedNetworkImage(
                      imageUrl: profilePath != null
                          ? TmdbImageHelper.profileUrl(context, profilePath)!
                          : '',
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: AppTheme.secondary),
                      errorWidget: (context, url, error) => Image.asset(
                        'assets/cast_placeholder.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Name
              Text(
                name,
                style: DesktopTypography.bodySecondary.copyWith(
                  color: isFocused ? Colors.white : AppTheme.textWhite,
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
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
      child: const SizedBox.shrink(),
    );
  }
}
