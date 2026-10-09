import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/core/constants/tmdb_image_helper.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/person.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class PersonFilmographyList extends StatelessWidget {
  final List<PersonCredit> credits;
  final ValueChanged<PersonCredit> onMediaTap;

  const PersonFilmographyList({
    super.key,
    required this.credits,
    required this.onMediaTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: credits.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = credits[index];
        final year = item.releaseYear;
        final title = item.title;
        final posterPath = item.posterPath;
        final isTv = item.mediaType == MediaKind.tv;
        final role = item.role ?? '';
        final rating = item.voteAverage;
        final thumbnailUrl = posterPath != null
            ? TmdbImageHelper.thumbnailUrl(posterPath)
            : null;

        return InkWell(
          onTap: () => onMediaTap(item),
          borderRadius: AppTheme.radius12,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.textWhite.withValues(alpha: 0.02),
              borderRadius: AppTheme.radius12,
              border: Border.all(
                color: AppTheme.textWhite.withValues(alpha: 0.05),
              ),
            ),
            child: Row(
              children: [
                // Year
                SizedBox(
                  width: 50,
                  child: Text(
                    year.isEmpty ? '-' : year,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Poster Small
                Container(
                  width: 48,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: AppTheme.radiusSm,
                    image: thumbnailUrl != null
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(
                              thumbnailUrl,
                              maxWidth: 100,
                              maxHeight: 150,
                            ),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: thumbnailUrl == null
                      ? Icon(
                          LucideIcons.film,
                          size: 16,
                          color: AppTheme.textWhite.withValues(alpha: 0.1),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: AppTheme.textWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isTv
                                  ? AppTheme.badgeResolution.withValues(alpha: 0.1)
                                  : AppTheme.accent.withValues(alpha: 0.1),
                              borderRadius: AppTheme.radiusSm,
                              border: Border.all(
                                color: (isTv
                                        ? AppTheme.badgeResolution
                                        : AppTheme.accent)
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              isTv
                                  ? l10n.personSeries.toUpperCase()
                                  : l10n.personMovie.toUpperCase(),
                              style: TextStyle(
                                color: isTv
                                    ? AppTheme.badgeResolution
                                    : AppTheme.accent,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        role,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Rating
                if (rating > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.1),
                      borderRadius: AppTheme.radiusSm,
                      border: Border.all(
                        color: AppTheme.success.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.star,
                          size: 10,
                          color: AppTheme.star,
                          fill: 1.0,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: AppTheme.success,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
