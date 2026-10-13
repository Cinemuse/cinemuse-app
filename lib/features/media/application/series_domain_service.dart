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
  int airedEpisodeCount(Map<String, dynamic> details) {
    final seasons = (details['seasons'] as List?) ?? const [];
    final lastAired = details['last_episode_to_air'] as Map?;
    final lastSeason = lastAired?['season_number'] as int? ?? 0;
    final lastEpisode = lastAired?['episode_number'] as int? ?? 0;
    final status = details['status'] as String?;
    final isEnded = status == 'Ended' || status == 'Canceled';
    final now = DateTime.now();

    var total = 0;
    for (final season in seasons) {
      final number = season['season_number'] as int? ?? 0;
      final count = season['episode_count'] as int? ?? 0;
      if (number <= 0) continue;
      if (lastAired != null) {
        if (number < lastSeason) total += count;
        if (number == lastSeason) total += min(count, lastEpisode);
      } else if (isEnded) {
        total += count;
      } else {
        final airDate = DateTime.tryParse('${season['air_date'] ?? ''}');
        if (airDate != null && !airDate.isAfter(now)) total += count;
      }
    }
    return total;
  }

  /// Calculates percentage and episode watch counts for a series.
  ({int percentage, int watchedCount, int totalCount})?
  calculateSeriesProgress({
    Map<String, dynamic>? details,
    Map<String, dynamic>? seriesDetails,
    Map<String, int>? watchedEpisodesMap,
    Map<String, int>? watchedMap,
  }) {
    final showDetails = seriesDetails ?? details;
    if (showDetails == null) return null;
    final seasons = showDetails['seasons'] as List?;
    if (seasons == null) return null;

    final resolvedWatchedMap = watchedEpisodesMap ?? watchedMap ?? const {};

    final totalEpisodes = airedEpisodeCount(showDetails);

    final watchedEpisodesCount = resolvedWatchedMap.entries.where((entry) {
      final seasonNum = int.tryParse(entry.key.split('-').first) ?? 0;
      return seasonNum > 0 && entry.value > 0;
    }).length;

    if (totalEpisodes == 0) return null;

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
    Map<String, dynamic>? episodeProgressMap,
    Map<String, dynamic>? watchedData,
  }) {
    final epKey = '$seasonNumber-$episodeNumber';
    if (episodeProgress != null && episodeProgress.containsKey(epKey)) {
      final history = episodeProgress[epKey]!;
      if (history.status == WatchStatus.watching &&
          history.totalDuration != null &&
          history.totalDuration! > 0) {
        return history.progressSeconds / history.totalDuration!;
      }
    }

    if (episodeProgressMap != null && episodeProgressMap.containsKey(epKey)) {
      final dynamic history = episodeProgressMap[epKey];
      if (history is WatchHistory) {
        if (history.status == WatchStatus.watching &&
            history.totalDuration != null &&
            history.totalDuration! > 0) {
          return history.progressSeconds / history.totalDuration!;
        }
      } else if (history is Map) {
        final progressSeconds = history['progress_seconds'] as int? ?? 0;
        final totalDuration = history['total_duration'] as int? ?? 0;
        final status = history['status']?.toString();
        if (status == 'watching' && totalDuration > 0) {
          return progressSeconds / totalDuration;
        }
      }
    }

    if (watchedData != null) {
      final lastSeason = watchedData['season'] as int?;
      final lastEpisode = watchedData['episode'] as int?;
      if (lastSeason == seasonNumber && lastEpisode == episodeNumber) {
        final progress = watchedData['progress_seconds'] as int? ?? 0;
        final total = watchedData['total_duration'] as int? ?? 0;
        if (total > 0) {
          return progress / total;
        }
      }
    }

    return null;
  }

  /// Returns list of un-watched episodes preceding the targeted episode in the series.
  List<({int season, int episode})> findMissingPrecedingEpisodes({
    Map<String, dynamic>? seriesDetails,
    List<dynamic>? seasons,
    required int currentSeason,
    required int currentEpisode,
    Map<String, int>? watchedEpisodesCount,
  }) {
    final List<({int season, int episode})> missing = [];
    final seasonList = seasons ?? (seriesDetails?['seasons'] as List? ?? []);
    final resolvedWatched = watchedEpisodesCount ?? const {};

    for (final season in seasonList) {
      final sNum = season['season_number'] as int? ?? 0;
      if (sNum == 0) continue;
      if (sNum > currentSeason) break;

      final epCount = season['episode_count'] as int? ?? 0;
      final maxE = (sNum == currentSeason) ? currentEpisode - 1 : epCount;

      for (int e = 1; e <= maxE; e++) {
        final key = '$sNum-$e';
        if ((resolvedWatched[key] ?? 0) == 0) {
          missing.add((season: sNum, episode: e));
        }
      }
    }
    return missing;
  }
}
