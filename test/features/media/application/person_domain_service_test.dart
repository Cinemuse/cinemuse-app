import 'package:cinemuse_app/features/media/application/person_domain_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PersonDomainService', () {
    final referenceDate = DateTime(2026, 1, 1);

    test('calculateSeenStats correctly computes stats for released items', () {
      final cast = [
        {
          'id': 101,
          'title': 'Released Movie 1',
          'release_date': '2020-05-10',
        },
        {
          'id': 102,
          'title': 'Unreleased Movie',
          'release_date': '2027-01-01',
        },
      ];
      final crew = [
        {
          'id': 103,
          'title': 'Released Movie 2',
          'release_date': '2021-08-15',
        },
        {
          // Duplicate of 101 in crew
          'id': 101,
          'title': 'Released Movie 1',
          'release_date': '2020-05-10',
        },
      ];

      final watchHistory = {
        '101': {'watched': true},
      };

      final stats = PersonDomainService.calculateSeenStats(
        cast: cast,
        crew: crew,
        watchHistory: watchHistory,
        referenceDate: referenceDate,
      );

      // Total released: 101 and 103 (2 items). 102 is unreleased. Duplicate 101 is counted once.
      expect(stats.totalReleased, 2);
      expect(stats.watchedCount, 1);
      expect(stats.watchedPercent, 50);
    });

    test('calculateSeenStats handles empty credits gracefully', () {
      final stats = PersonDomainService.calculateSeenStats(
        cast: [],
        crew: [],
        watchHistory: {},
        referenceDate: referenceDate,
      );

      expect(stats.totalReleased, 0);
      expect(stats.watchedCount, 0);
      expect(stats.watchedPercent, 0);
    });

    test('extractTopKnownFor sorts by vote_count descending', () {
      final cast = [
        {'id': 1, 'title': 'Movie A', 'vote_count': 500},
        {'id': 2, 'title': 'Movie B', 'vote_count': 5000},
        {'id': 3, 'title': 'Movie C', 'vote_count': 1200},
      ];

      final top = PersonDomainService.extractTopKnownFor(cast, limit: 2);

      expect(top.length, 2);
      expect(top[0]['id'], 2);
      expect(top[1]['id'], 3);
    });

    test('processFilmography deduplicates, sorts by date desc, and filters hidden items', () {
      final cast = [
        {
          'id': 1,
          'title': 'Old Movie',
          'release_date': '2010-01-01',
          'genre_ids': [18],
        },
        {
          'id': 2,
          'title': 'New Movie',
          'release_date': '2024-01-01',
          'genre_ids': [28],
        },
        {
          'id': 3,
          'title': 'The 90th Academy Awards',
          'release_date': '2018-03-04',
          'genre_ids': [10763],
        },
      ];
      final crew = [
        {
          // Duplicate of 2
          'id': 2,
          'title': 'New Movie',
          'release_date': '2024-01-01',
          'genre_ids': [28],
        },
      ];

      // When hidden items are filtered (showHidden == false)
      final filtered = PersonDomainService.processFilmography(
        cast: cast,
        crew: crew,
        showHidden: false,
      );

      expect(filtered.length, 2);
      expect(filtered[0]['id'], 2); // 2024
      expect(filtered[1]['id'], 1); // 2010

      // When hidden items are shown (showHidden == true)
      final all = PersonDomainService.processFilmography(
        cast: cast,
        crew: crew,
        showHidden: true,
      );

      expect(all.length, 3);
      expect(all[0]['id'], 2);
      expect(all[1]['id'], 3);
      expect(all[2]['id'], 1);
    });
  });
}
