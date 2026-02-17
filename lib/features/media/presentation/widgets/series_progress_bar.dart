import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class SeriesProgressBar extends ConsumerWidget {
  final Map<String, dynamic> details;

  const SeriesProgressBar({
    super.key,
    required this.details,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tmdbId = details['id'] as int;
    
    final watchedEpisodesMap = ref.watch(watchedEpisodesMapProvider(tmdbId));
    final progress = _calculateProgress(watchedEpisodesMap);
    
    if (progress == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.detailsSeriesProgress.toUpperCase(),
                style: GoogleFonts.firaCode(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '${progress.percentage}% (${progress.watchedCount}/${progress.totalCount})',
                style: GoogleFonts.firaCode(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress.percentage / 100,
              backgroundColor: AppTheme.textWhite.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  ({int percentage, int watchedCount, int totalCount})? _calculateProgress(Map<String, int> watchedMap) {
    final seasons = details['seasons'] as List?;
    if (seasons == null) return null;

    int totalEpisodes = 0;
    int watchedEpisodesCount = 0;

    final now = DateTime.now();
    final lastAired = details['last_episode_to_air'];

    for (var season in seasons) {
      final seasonNum = season['season_number'] as int? ?? 0;
      if (seasonNum > 0 && season['episode_count'] != null) {
        if (season['air_date'] == null) continue;
        final airDate = DateTime.tryParse(season['air_date']);
        if (airDate == null || airDate.isAfter(now)) continue;

        if (lastAired != null && seasonNum == lastAired['season_number']) {
          totalEpisodes += (lastAired['episode_number'] as int);
        } else if (lastAired == null || seasonNum < (lastAired['season_number'] as int)) {
          totalEpisodes += (season['episode_count'] as int);
        }
      }
    }

    // Correctly count watched episodes from the map
    watchedEpisodesCount = watchedMap.values.where((count) => count > 0).length;

    if (totalEpisodes == 0) return null;

    return (
      percentage: ((watchedEpisodesCount / totalEpisodes) * 100).round().clamp(0, 100),
      watchedCount: watchedEpisodesCount,
      totalCount: totalEpisodes,
    );
  }
}
