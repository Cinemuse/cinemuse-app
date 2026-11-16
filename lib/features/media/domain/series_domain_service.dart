import 'dart:math';

import 'package:cinemuse_app/features/media/domain/episode_item.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';

class NextEpisodeInfo {
  final int season;
  final int episode;
  final String? title;

  NextEpisodeInfo({required this.season, required this.episode, this.title});
}

class SeriesDomainService {
  /// Determines the next episode and its release state.
  /// Returns [NextEpisodeInfo] and whether it is already aired.
  /// After a special comes the next special, and nothing after the last one:
  /// specials never lead into a regular season (REV-264).
  ({NextEpisodeInfo? next, bool isAired}) getNextEpisode(
    MediaItem series,
    int currentSeason,
    int currentEpisode,
  ) {
    int? nextS;
    int? nextE;

    final seasons = series.seasons ?? const <SeasonSummary>[];

    // 1. Find Current Season Info
    final currentSeasonData = seasons
        .where((s) => s.seasonNumber == currentSeason)
        .firstOrNull;

    if (currentSeasonData != null) {
      final episodeCount = currentSeasonData.episodeCount ?? 0;
      if (currentEpisode < episodeCount) {
        // Next episode in same season
        nextS = currentSeason;
        nextE = currentEpisode + 1;
      } else if (currentSeason > 0) {
        // Check for next season
        final nextSeasons =
            seasons
                .map((s) => s.seasonNumber)
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
    final lastAired = series.lastAiredEpisode;
    if (lastAired != null) {
      final (season: lastS, episode: lastE) = lastAired;

      if (nextS > lastS || (nextS == lastS && nextE > lastE)) {
        return (next: nextInfo, isAired: false);
      }
    }

    return (next: nextInfo, isAired: true);
  }

  /// The episode Continue Watching moves on from after [watched] are logged:
  /// the highest of them. Specials are extras (REV-264): after only
  /// specials it is [highestRegular], the highest regular episode logged,
  /// or "before season 1 episode 1" when none is.
  static ({int season, int episode}) episodeToContinueFrom(
    List<({int season, int episode})> watched, {
    ({int season, int episode})? highestRegular,
  }) {
    final latest = watched.reduce(
      (a, b) =>
          (b.season > a.season ||
              (b.season == a.season && b.episode > a.episode))
          ? b
          : a,
    );
    if (latest.season > 0) return latest;
    return highestRegular ?? (season: 1, episode: 0);
  }

  /// How many regular episodes (no specials) have aired. The one rule for
  /// the "fully watched" badge and the progress bar (REV-198).
  int airedEpisodeCount(MediaItem series) => airedEpisodes(series).length;

  /// The regular episodes (no specials) that have aired, in order: what
  /// "mark all" logs (REV-205). Same rule as [airedEpisodeCount], so marking
  /// all makes the show fully watched.
  List<({int season, int episode})> airedEpisodes(MediaItem series) {
    final seasons = series.seasons ?? const <SeasonSummary>[];
    final lastAired = series.lastAiredEpisode;
    final lastSeason = lastAired?.season ?? 0;
    final lastEpisode = lastAired?.episode ?? 0;
    final status = series.status;
    final isEnded = status == 'Ended' || status == 'Canceled';
    final now = DateTime.now();

    final aired = <({int season, int episode})>[];
    for (final season in seasons) {
      final number = season.seasonNumber;
      final count = season.episodeCount ?? 0;
      if (number <= 0) continue;
      var airedCount = 0;
      if (lastAired != null) {
        if (number < lastSeason) airedCount = count;
        if (number == lastSeason) airedCount = min(count, lastEpisode);
      } else if (isEnded) {
        airedCount = count;
      } else {
        final airDate = season.airDate;
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
    MediaItem? series,
    Map<String, int> watchedEpisodesMap = const {},
  }) {
    if (series == null || series.seasons == null) return null;

    final totalEpisodes = airedEpisodeCount(series);
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
    required List<SeasonSummary> seasons,
    required int currentSeason,
    required int currentEpisode,
    Map<String, int> watchedEpisodesCount = const {},
  }) {
    final List<({int season, int episode})> missing = [];

    for (final season in seasons) {
      final sNum = season.seasonNumber;
      if (sNum == 0) continue;
      if (sNum > currentSeason) break;

      final epCount = season.episodeCount ?? 0;
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
