import 'package:cinemuse_app/features/profile/data/agenda_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('firstAiredEpisodeAfter', () {
    Map<String, dynamic> ep(int season, int episode, String? airDate) => {
      'season_number': season,
      'episode_number': episode,
      'air_date': airDate,
    };

    final season2 = [
      ep(2, 1, '2026-09-01'),
      ep(2, 2, '2026-09-08'),
      ep(2, 3, '2026-09-15'),
      ep(2, 4, '2026-09-22'),
      ep(2, 5, '2026-09-29'),
      ep(2, 6, '2026-10-20'),
      ep(2, 7, null),
    ];

    test('picks the episode after the last one watched, not the newest', () {
      final next = firstAiredEpisodeAfter(
        season: 2,
        episode: 3,
        episodes: season2,
        todayStr: '2026-10-11',
      );

      expect(next, (season: 2, episode: 4));
    });

    test('returns null when nothing new has aired', () {
      final next = firstAiredEpisodeAfter(
        season: 2,
        episode: 5,
        episodes: season2,
        todayStr: '2026-10-11',
      );

      expect(next, isNull);
    });

    test('moves on to episode 1 of the next season', () {
      final next = firstAiredEpisodeAfter(
        season: 1,
        episode: 10,
        episodes: season2,
        todayStr: '2026-10-11',
      );

      expect(next, (season: 2, episode: 1));
    });

    test('returns null when the next episode is not in the cache', () {
      // The cache holds season 3 only, so season 2 can't be skipped.
      final next = firstAiredEpisodeAfter(
        season: 1,
        episode: 10,
        episodes: [ep(3, 1, '2026-10-01')],
        todayStr: '2026-10-11',
      );

      expect(next, isNull);
    });
  });
}
