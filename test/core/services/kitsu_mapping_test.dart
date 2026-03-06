import 'package:cinemuse_app/core/services/anime/kitsu_mapping_service.dart';
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
      
      when(() => mockDb.getAnimeMappingsByTmdbShow(85937))
          .thenAnswer((_) async => [mapping]);
      
      when(() => mockDb.getKitsuMapping(101922))
          .thenAnswer((_) async => AnimeKitsuMapping(anilistId: 101922, kitsuId: '41370', updatedAt: DateTime.now()));

      final result = await service.getMapping(tmdbId: 85937, type: 'tv', season: 1, episode: 10);
      
      expect(result?.kitsuId, '41370');
      expect(result?.absoluteEpisode, 10);
    });

    test('Calculates absolute episode for offset range (s2 e1 -> absolute 1)', () async {
      // Demon Slayer S2 maps to anilist 129874 (Entertainment District Arc)
      final mapping = AnimeExternalMapping(
        anilistId: 129874,
        anidbId: 1001,
        tmdbShowId: 85937,
        mappingsData: '{"s2": "e8-e18"}', // TMDB S2 E8 is Kitsu Arc E1
      );
      
      when(() => mockDb.getAnimeMappingsByTmdbShow(85937))
          .thenAnswer((_) async => [mapping]);
      
      when(() => mockDb.getKitsuMapping(129874))
          .thenAnswer((_) async => AnimeKitsuMapping(anilistId: 129874, kitsuId: '44081', updatedAt: DateTime.now()));

      final result = await service.getMapping(tmdbId: 85937, type: 'tv', season: 2, episode: 10);
      
      // S2 E10 - S2 E8 + 1 = 3
      expect(result?.kitsuId, '44081');
      expect(result?.absoluteEpisode, 3);
    });
    
    test('Handles open-ended ranges (e1089-)', () async {
      final mapping = AnimeExternalMapping(
        anilistId: 21,
        anidbId: 69,
        tmdbShowId: 37854,
        mappingsData: '{"s21": "e892-"}',
      );
      
      when(() => mockDb.getAnimeMappingsByTmdbShow(37854))
          .thenAnswer((_) async => [mapping]);
      
      when(() => mockDb.getKitsuMapping(21))
          .thenAnswer((_) async => AnimeKitsuMapping(anilistId: 21, kitsuId: '1', updatedAt: DateTime.now()));

      final result = await service.getMapping(tmdbId: 37854, type: 'tv', season: 21, episode: 1000);
      
      // 1000 - 892 + 1 = 109
      expect(result?.kitsuId, '1');
      expect(result?.absoluteEpisode, 109);
    });
  });
}
