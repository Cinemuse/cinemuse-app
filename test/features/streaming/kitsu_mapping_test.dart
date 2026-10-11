import 'package:cinemuse_app/features/streaming/anime/kitsu_mapping_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cinemuse_app/core/data/database.dart';
import 'package:dio/dio.dart';

class MockDio extends Mock implements Dio {}

class MockAppDatabase extends Mock implements AppDatabase {}

void main() {
  late KitsuMappingService service;
  late MockDio mockDio;
  late MockAppDatabase mockDb;

  setUp(() {
    mockDio = MockDio();
    mockDb = MockAppDatabase();
    service = KitsuMappingService(mockDio, mockDb);
  });

  group('KitsuMappingService - Episode Calculation', () {
    test('Calculates absolute episode for simple range (e1-e26)', () async {
      final mapping = AnimeExternalMapping(
        anilistId: 101922,
        anidbId: 1000,
        tmdbShowId: 85937,
        mappingsData: '{"s1": "e1-e26"}',
      );

      when(
        () => mockDb.getAnimeMappingsByTmdbShow(85937),
      ).thenAnswer((_) async => [mapping]);

      when(() => mockDb.getKitsuMapping(101922)).thenAnswer(
        (_) async => AnimeKitsuMapping(
          anilistId: 101922,
          kitsuId: '41370',
          updatedAt: DateTime.now(),
        ),
      );

      final result = await service.getMapping(
        tmdbId: 85937,
        type: 'tv',
        season: 1,
        episode: 10,
      );

      expect(result?.kitsuId, '41370');
      expect(result?.absoluteEpisode, 10);
    });

    test(
      'Calculates absolute episode for offset range (s2 e1 -> absolute 1)',
      () async {
        // Demon Slayer S2 maps to anilist 129874 (Entertainment District Arc)
        final mapping = AnimeExternalMapping(
          anilistId: 129874,
          anidbId: 1001,
          tmdbShowId: 85937,
          mappingsData: '{"s2": "e8-e18"}', // TMDB S2 E8 is Kitsu Arc E1
        );

        when(
          () => mockDb.getAnimeMappingsByTmdbShow(85937),
        ).thenAnswer((_) async => [mapping]);

        when(() => mockDb.getKitsuMapping(129874)).thenAnswer(
          (_) async => AnimeKitsuMapping(
            anilistId: 129874,
            kitsuId: '44081',
            updatedAt: DateTime.now(),
          ),
        );

        final result = await service.getMapping(
          tmdbId: 85937,
          type: 'tv',
          season: 2,
          episode: 10,
        );

        // S2 E10 - S2 E8 + 1 = 3
        expect(result?.kitsuId, '44081');
        expect(result?.absoluteEpisode, 3);
      },
    );

    test('Handles open-ended ranges (e1089-)', () async {
      final mapping = AnimeExternalMapping(
        anilistId: 21,
        anidbId: 69,
        tmdbShowId: 37854,
        mappingsData: '{"s21": "e892-"}',
      );

      when(
        () => mockDb.getAnimeMappingsByTmdbShow(37854),
      ).thenAnswer((_) async => [mapping]);

      when(() => mockDb.getKitsuMapping(21)).thenAnswer(
        (_) async => AnimeKitsuMapping(
          anilistId: 21,
          kitsuId: '1',
          updatedAt: DateTime.now(),
        ),
      );

      final result = await service.getMapping(
        tmdbId: 37854,
        type: 'tv',
        season: 21,
        episode: 1000,
      );

      // 1000 - 892 + 1 = 109
      expect(result?.kitsuId, '1');
      expect(result?.absoluteEpisode, 109);
    });
  });

  group('KitsuMappingService - fallback (REV-233)', () {
    // Attack on Titan (TMDB 1429): the rows cover S4 only up to E28.
    final rows = [
      AnimeExternalMapping(
        anilistId: 1,
        anidbId: null,
        tmdbShowId: 1429,
        mappingsData: '{"s0": "e1"}',
      ),
      AnimeExternalMapping(
        anilistId: 2,
        anidbId: 2002,
        tmdbShowId: 1429,
        mappingsData: '{"s4": "e1-e16"}',
      ),
      AnimeExternalMapping(
        anilistId: 3,
        anidbId: 2003,
        tmdbShowId: 1429,
        mappingsData: '{"s4": "e17-e28"}',
      ),
    ];

    void stubKitsu(int anilistId, String kitsuId, int? episodeCount) {
      when(() => mockDb.getKitsuMapping(anilistId)).thenAnswer(
        (_) async => AnimeKitsuMapping(
          anilistId: anilistId,
          kitsuId: kitsuId,
          episodeCount: episodeCount,
          updatedAt: DateTime.now(),
        ),
      );
    }

    setUp(() {
      stubKitsu(1, '7694', 1);
      stubKitsu(2, '42422', 16);
      stubKitsu(3, '43000', 12);
    });

    test('an episode no row covers gets no mapping, not a special', () async {
      when(
        () => mockDb.getAnimeMappingsByTmdbShow(1429),
      ).thenAnswer((_) async => [...rows]);

      final result = await service.getMapping(
        tmdbId: 1429,
        type: 'tv',
        season: 4,
        episode: 30,
      );

      expect(result, isNull);
    });

    test('a row without season data is still used as a guess', () async {
      when(() => mockDb.getAnimeMappingsByTmdbShow(1429)).thenAnswer(
        (_) async => [
          ...rows,
          AnimeExternalMapping(anilistId: 4, anidbId: 2004, tmdbShowId: 1429),
        ],
      );
      stubKitsu(4, '44000', null);

      final result = await service.getMapping(
        tmdbId: 1429,
        type: 'tv',
        season: 4,
        episode: 30,
      );

      expect(result?.kitsuId, '44000');
      expect(result?.absoluteEpisode, 30);
    });
  });
}
