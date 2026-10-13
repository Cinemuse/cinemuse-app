import 'package:cinemuse_app/features/media/application/series_domain_service.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SeriesDomainService', () {
    late SeriesDomainService service;

    setUp(() {
      service = SeriesDomainService();
    });

    test(
      'calculateReleasedEpisodes counts only released episodes across regular seasons',
      () {
        final details = {
          'seasons': [
            {
              'season_number': 0, // Specials should be skipped
              'episode_count': 5,
              'air_date': '2020-01-01',
            },
            {'season_number': 1, 'episode_count': 10, 'air_date': '2020-01-01'},
            {'season_number': 2, 'episode_count': 8, 'air_date': '2021-01-01'},
          ],
          'last_episode_to_air': {'season_number': 2, 'episode_number': 4},
        };

        final count = service.airedEpisodeCount(details);

        // Season 1 has 10 released. Season 2 has 4 aired. Total = 14.
        expect(count, 14);
      },
    );

    // REV-198: the badge's count skipped a season with no air_date even
    // when TMDB said its episodes had aired; the progress bar didn't.
    test('airedEpisodeCount trusts the last aired episode over air dates', () {
      final details = {
        'status': 'Returning Series',
        'seasons': [
          {'season_number': 1, 'episode_count': 10},
          {'season_number': 2, 'episode_count': 8},
        ],
        'last_episode_to_air': {'season_number': 2, 'episode_number': 3},
      };

      expect(service.airedEpisodeCount(details), 13);
      expect(service.calculateSeriesProgress(details: details)!.totalCount, 13);
    });

    test(
      'calculateSeriesProgress computes status and progress ratio accurately',
      () {
        final details = {
          'number_of_episodes': 10,
          'status': 'Ended',
          'seasons': [
            {'season_number': 1, 'episode_count': 10},
          ],
        };

        // 5 episodes watched
        final watchedEpisodesMap = {for (var i = 1; i <= 5; i++) '1-$i': 1};

        final progress = service.calculateSeriesProgress(
          details: details,
          watchedEpisodesMap: watchedEpisodesMap,
        );

        expect(progress, isNotNull);
        expect(progress!.totalCount, 10);
        expect(progress.watchedCount, 5);
        expect(progress.percentage, 50);
      },
    );

    test(
      'calculateResumePercentage parses duration and position correctly with WatchHistory',
      () {
        final history = WatchHistory(
          userId: 'user_1',
          tmdbId: 123,
          mediaType: MediaKind.tv,
          season: 1,
          episode: 2,
          progressSeconds: 1500,
          totalDuration: 6000,
          status: WatchStatus.watching,
          lastWatchedAt: DateTime.now(),
        );

        final percent = service.calculateResumePercentage(
          seasonNumber: 1,
          episodeNumber: 2,
          episodeProgress: {'1-2': history},
        );

        expect(percent, 0.25);
      },
    );

    test(
      'findMissingPrecedingEpisodes detects unwatched preceding episodes',
      () {
        final seasons = [
          {'season_number': 1, 'episode_count': 4},
        ];

        // Only episode 1 and 4 watched
        final watchedEpisodesCount = {'1-1': 1, '1-4': 1};

        final missing = service.findMissingPrecedingEpisodes(
          seasons: seasons,
          currentSeason: 1,
          currentEpisode: 4,
          watchedEpisodesCount: watchedEpisodesCount,
        );

        // Episodes 2 and 3 should be missing
        expect(missing.length, 2);
        expect(missing[0].season, 1);
        expect(missing[0].episode, 2);
        expect(missing[1].season, 1);
        expect(missing[1].episode, 3);
      },
    );
  });
}
