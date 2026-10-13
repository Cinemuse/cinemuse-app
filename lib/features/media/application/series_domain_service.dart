import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';

class NextEpisodeInfo {
  final int season;
  final int episode;
  final String? title;

  NextEpisodeInfo({required this.season, required this.episode, this.title});
}

final seriesDomainServiceProvider = Provider((ref) => SeriesDomainService());

class SeriesDomainService {
  /// Determines the next episode and its release state.
  /// Returns [NextEpisodeInfo] and whether it is already aired.
  ({NextEpisodeInfo? next, bool isAired}) getNextEpisode(
    Map<String, dynamic> seriesDetails,
    int currentSeason,
    int currentEpisode,
  ) {
    int? nextS;
    int? nextE;

    final seasons = seriesDetails['seasons'] as List? ?? [];

    // 1. Find Current Season Info
    final currentSeasonData = seasons.firstWhere(
      (s) => s['season_number'] == currentSeason,
      orElse: () => null,
    );

    if (currentSeasonData != null) {
      final episodeCount = currentSeasonData['episode_count'] as int? ?? 0;
      if (currentEpisode < episodeCount) {
        // Next episode in same season
        nextS = currentSeason;
        nextE = currentEpisode + 1;
      } else {
        // Check for next season
        final nextSeasons =
            seasons
                .map((s) => s['season_number'] as int? ?? 0)
                .where((n) => n > currentSeason)
                .toList()
              ..sort();

        if (nextSeasons.isNotEmpty) {
          nextS = nextSeasons.first;
          nextE = 1;
        }
      }
    }

    if (nextS == null || nextE == null) {
      return (next: null, isAired: false);
    }

    final nextInfo = NextEpisodeInfo(season: nextS, episode: nextE);

    // 2. Verify Release Status
    final lastAired = seriesDetails['last_episode_to_air'];
    if (lastAired != null) {
      final lastS = lastAired['season_number'] as int? ?? 0;
      final lastE = lastAired['episode_number'] as int? ?? 0;

      if (nextS > lastS || (nextS == lastS && nextE > lastE)) {
        return (next: nextInfo, isAired: false);
      }
    }

    return (next: nextInfo, isAired: true);
  }

  /// How many regular episodes (no specials) have aired. The one rule for
  /// the "fully watched" badge and the progress bar (REV-198).
  int airedEpisodeCount(Map<String, dynamic> details) =>
      airedEpisodes(details).length;

  /// The regular episodes (no specials) that have aired, in order: what
  /// "mark all" logs (REV-205). Same rule as [airedEpisodeCount], so marking
  /// all makes the show fully watched.
  List<({int season, int episode})> airedEpisodes(
    Map<String, dynamic> details,
  ) {
    final seasons = (details['seasons'] as List?) ?? const [];
    final lastAired = details['last_episode_to_air'] as Map?;
    final lastSeason = lastAired?['season_number'] as int? ?? 0;
    final lastEpisode = lastAired?['episode_number'] as int? ?? 0;
    final status = details['status'] as String?;
    final isEnded = status == 'Ended' || status == 'Canceled';
    final now = DateTime.now();

    final aired = <({int season, int episode})>[];
    for (final season in seasons) {
      final number = season['season_number'] as int? ?? 0;
      final count = season['episode_count'] as int? ?? 0;
      if (number <= 0) continue;
      var airedCount = 0;
      if (lastAired != null) {
        if (number < lastSeason) airedCount = count;
        if (number == lastSeason) airedCount = min(count, lastEpisode);
      } else if (isEnded) {
        airedCount = count;
      } else {
        final airDate = DateTime.tryParse('${season['air_date'] ?? ''}');
        if (airDate != null && !airDate.isAfter(now)) airedCount = count;
      }
      for (var e = 1; e <= airedCount; e++) {
        aired.add((season: number, episode: e));
      }
    }
    return aired;
  }

  /// Calculates percentage and episode watch counts for a series.
  ({int percentage, int watchedCount, int totalCount})?
  calculateSeriesProgress({
    Map<String, dynamic>? details,
    Map<String, int> watchedEpisodesMap = const {},
  }) {
    if (details == null || details['seasons'] is! List) return null;

    final totalEpisodes = airedEpisodeCount(details);
    if (totalEpisodes == 0) return null;

    final watchedEpisodesCount = watchedEpisodesMap.entries.where((entry) {
      final seasonNum = int.tryParse(entry.key.split('-').first) ?? 0;
      return seasonNum > 0 && entry.value > 0;
    }).length;

    return (
      percentage: ((watchedEpisodesCount / totalEpisodes) * 100).round().clamp(
        0,
        100,
      ),
      watchedCount: watchedEpisodesCount,
      totalCount: totalEpisodes,
    );
  }

  /// Calculates resume percentage (0.0 to 1.0) for an episode.
  double? calculateResumePercentage({
    required int seasonNumber,
    required int episodeNumber,
    Map<String, WatchHistory>? episodeProgress,
  }) {
    final history = episodeProgress?['$seasonNumber-$episodeNumber'];
    final total = history?.totalDuration ?? 0;
    if (history == null || history.status != WatchStatus.watching) return null;
    if (total <= 0) return null;
    return history.progressSeconds / total;
  }

  /// Returns list of un-watched episodes preceding the targeted episode in the series.
  List<({int season, int episode})> findMissingPrecedingEpisodes({
    required List<dynamic> seasons,
    required int currentSeason,
    required int currentEpisode,
    Map<String, int> watchedEpisodesCount = const {},
  }) {
    final List<({int season, int episode})> missing = [];

    for (final season in seasons) {
      final sNum = season['season_number'] as int? ?? 0;
      if (sNum == 0) continue;
      if (sNum > currentSeason) break;

      final epCount = season['episode_count'] as int? ?? 0;
      final maxE = (sNum == currentSeason) ? currentEpisode - 1 : epCount;

      for (int e = 1; e <= maxE; e++) {
        if ((watchedEpisodesCount['$sNum-$e'] ?? 0) == 0) {
          missing.add((season: sNum, episode: e));
        }
      }
    }
    return missing;
  }
}
