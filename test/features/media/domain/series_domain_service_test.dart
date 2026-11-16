import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/features/media/domain/series_domain_service.dart';

/// A show as the app reads it from TMDB's details answer [tmdb].
MediaItem _show(Map<String, dynamic> tmdb) =>
    MediaItem.fromTmdbDetails({'id': 1, ...tmdb}, MediaKind.tv);

void main() {
  group('SeriesDomainService', () {
    late SeriesDomainService service;

    setUp(() {
      service = SeriesDomainService();
    });

    test(
      'calculateReleasedEpisodes counts only released episodes across regular seasons',
      () {
        final details = _show({
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
        });

        final count = service.airedEpisodeCount(details);

        // Season 1 has 10 released. Season 2 has 4 aired. Total = 14.
        expect(count, 14);
      },
    );

    // REV-198: the badge's count skipped a season with no air_date even
    // when TMDB said its episodes had aired; the progress bar didn't.
    test('airedEpisodeCount trusts the last aired episode over air dates', () {
      final details = _show({
        'status': 'Returning Series',
        'seasons': [
          {'season_number': 1, 'episode_count': 10},
          {'season_number': 2, 'episode_count': 8},
        ],
        'last_episode_to_air': {'season_number': 2, 'episode_number': 3},
      });

      expect(service.airedEpisodeCount(details), 13);
      expect(service.calculateSeriesProgress(series: details)!.totalCount, 13);
    });

    // REV-205: "mark all" had its own loop that skipped seasons with no
    // air_date, so marking all could leave the show not fully watched.
    test('airedEpisodes lists what airedEpisodeCount counts', () {
      final details = _show({
        'status': 'Returning Series',
        'seasons': [
          {'season_number': 0, 'episode_count': 2, 'air_date': '2019-01-01'},
          {'season_number': 1, 'episode_count': 2},
          {'season_number': 2, 'episode_count': 5, 'air_date': '2021-01-01'},
          {'season_number': 3, 'episode_count': 6, 'air_date': '2099-01-01'},
        ],
        'last_episode_to_air': {'season_number': 2, 'episode_number': 3},
      });

      final aired = service.airedEpisodes(details);

      expect(aired, [
        (season: 1, episode: 1),
        (season: 1, episode: 2),
        (season: 2, episode: 1),
        (season: 2, episode: 2),
        (season: 2, episode: 3),
      ]);
      expect(service.airedEpisodeCount(details), aired.length);
    });

    test(
      'calculateSeriesProgress computes status and progress ratio accurately',
      () {
        final details = _show({
          'number_of_episodes': 10,
          'status': 'Ended',
          'seasons': [
            {'season_number': 1, 'episode_count': 10},
          ],
        });

        // 5 episodes watched
        final watchedEpisodesMap = {for (var i = 1; i <= 5; i++) '1-$i': 1};

        final progress = service.calculateSeriesProgress(
          series: details,
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
        final seasons = _show({
          'seasons': [
            {'season_number': 1, 'episode_count': 4},
          ],
        }).seasons!;

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

  // REV-264: specials (season 0) are extras, never part of the run.
  group('specials', () {
    final service = SeriesDomainService();
    final details = _show({
      'status': 'Returning Series',
      'seasons': <dynamic>[
        {'season_number': 0, 'episode_count': 3},
        {'season_number': 1, 'episode_count': 2},
        {'season_number': 2, 'episode_count': 5},
      ],
      'last_episode_to_air': {'season_number': 2, 'episode_number': 4},
    });

    (int, int)? nextAfter(int season, int episode) {
      final next = service.getNextEpisode(details, season, episode).next;
      return next == null ? null : (next.season, next.episode);
    }

    test('after a special comes the next special', () {
      expect(nextAfter(0, 1), (0, 2));
    });

    test('nothing comes after the last special', () {
      expect(nextAfter(0, 3), isNull);
    });

    test('regular episodes never lead into the specials', () {
      expect(nextAfter(1, 2), (2, 1));
    });

    test('Continue Watching moves on from the highest watched episode', () {
      final from = SeriesDomainService.episodeToContinueFrom(
        [
          (season: 1, episode: 2),
          (season: 0, episode: 3),
          (season: 2, episode: 1),
        ],
        highestRegular: (season: 1, episode: 1),
      );

      expect(from, (season: 2, episode: 1));
    });

    test('after only specials it moves on from the highest regular one', () {
      final from = SeriesDomainService.episodeToContinueFrom(
        [(season: 0, episode: 1), (season: 0, episode: 3)],
        highestRegular: (season: 2, episode: 4),
      );

      expect(from, (season: 2, episode: 4));
      expect(nextAfter(from.season, from.episode), (2, 5));
    });

    test('with no regular episode logged it starts the show', () {
      final from = SeriesDomainService.episodeToContinueFrom([
        (season: 0, episode: 2),
      ]);

      expect(nextAfter(from.season, from.episode), (1, 1));
    });

    test('watched specials never count toward the progress bar', () {
      final progress = service.calculateSeriesProgress(
        series: details,
        watchedEpisodesMap: {'0-1': 1, '0-2': 1, '0-3': 1, '1-1': 1},
      )!;

      expect(progress.watchedCount, 1);
      expect(progress.totalCount, 6);
    });

    test('ticking an episode never asks about missed specials', () {
      final missing = service.findMissingPrecedingEpisodes(
        seasons: details.seasons!,
        currentSeason: 1,
        currentEpisode: 2,
      );

      expect(missing, [(season: 1, episode: 1)]);
    });

    test('ticking a special never asks about earlier episodes', () {
      final missing = service.findMissingPrecedingEpisodes(
        seasons: details.seasons!,
        currentSeason: 0,
        currentEpisode: 3,
      );

      expect(missing, isEmpty);
    });
  });
}
