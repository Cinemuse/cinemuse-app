import 'package:flutter_riverpod/flutter_riverpod.dart';

class NextEpisodeInfo {
  final int season;
  final int episode;
  final String? title;

  NextEpisodeInfo({
    required this.season,
    required this.episode,
    this.title,
  });

  Map<String, dynamic> toJson() => {
    'season': season,
    'episode': episode,
    'title': title,
  };
}

enum SeriesProgressState {
  watchingNext,
  caughtUp,
  finished,
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
        final nextSeasons = seasons
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
}
