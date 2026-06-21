import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/hover_scale.dart';
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Photo
              AspectRatio(
                aspectRatio: 2 / 3,
                child: HoverScale(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: profilePath != null
                          ? TmdbImageHelper.profileUrl(context, profilePath)!
                          : '', // Provide an empty string or placeholder URL if profilePath is null
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
                  color: AppTheme.textWhite,
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
        ),
      ),
    );
  }
}
