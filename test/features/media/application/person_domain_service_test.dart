import 'package:cinemuse_app/features/media/application/person_domain_service.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/person.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PersonDomainService', () {
    final referenceDate = DateTime(2026, 1, 1);

    test('calculateSeenStats correctly computes stats for released items', () {
      final cast = [
        PersonCredit(
          id: 101,
          mediaType: MediaKind.movie,
          title: 'Released Movie 1',
          releaseDate: DateTime(2020, 5, 10),
        ),
        PersonCredit(
          id: 102,
          mediaType: MediaKind.movie,
          title: 'Unreleased Movie',
          releaseDate: DateTime(2027, 1, 1),
        ),
      ];
      final crew = [
        PersonCredit(
          id: 103,
          mediaType: MediaKind.movie,
          title: 'Released Movie 2',
          releaseDate: DateTime(2021, 8, 15),
        ),
        PersonCredit(
          // Duplicate of 101 in crew
          id: 101,
          mediaType: MediaKind.movie,
          title: 'Released Movie 1',
          releaseDate: DateTime(2020, 5, 10),
        ),
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
        const PersonCredit(
          id: 1,
          mediaType: MediaKind.movie,
          title: 'Movie A',
          voteCount: 500,
        ),
        const PersonCredit(
          id: 2,
          mediaType: MediaKind.movie,
          title: 'Movie B',
          voteCount: 5000,
        ),
        const PersonCredit(
          id: 3,
          mediaType: MediaKind.movie,
          title: 'Movie C',
          voteCount: 1200,
        ),
      ];

      final top = PersonDomainService.extractTopKnownFor(cast, limit: 2);

      expect(top.length, 2);
      expect(top[0].id, 2);
      expect(top[1].id, 3);
    });

    test('processFilmography deduplicates, sorts by date desc, and filters hidden items', () {
      final cast = [
        PersonCredit(
          id: 1,
          mediaType: MediaKind.movie,
          title: 'Old Movie',
          releaseDate: DateTime(2010, 1, 1),
          genreIds: const [18],
        ),
        PersonCredit(
          id: 2,
          mediaType: MediaKind.movie,
          title: 'New Movie',
          releaseDate: DateTime(2024, 1, 1),
          genreIds: const [28],
        ),
        PersonCredit(
          id: 3,
          mediaType: MediaKind.movie,
          title: 'The 90th Academy Awards',
          releaseDate: DateTime(2018, 3, 4),
          genreIds: const [10763],
        ),
      ];
      final crew = [
        PersonCredit(
          // Duplicate of 2
          id: 2,
          mediaType: MediaKind.movie,
          title: 'New Movie',
          releaseDate: DateTime(2024, 1, 1),
          genreIds: const [28],
        ),
      ];

      // When hidden items are filtered (showHidden == false)
      final filtered = PersonDomainService.processFilmography(
        cast: cast,
        crew: crew,
        showHidden: false,
      );

      expect(filtered.length, 2);
      expect(filtered[0].id, 2); // 2024
      expect(filtered[1].id, 1); // 2010

      // When hidden items are shown (showHidden == true)
      final all = PersonDomainService.processFilmography(
        cast: cast,
        crew: crew,
        showHidden: true,
      );

      expect(all.length, 3);
      expect(all[0].id, 2);
      expect(all[1].id, 3);
      expect(all[2].id, 1);
    });
  });
}
