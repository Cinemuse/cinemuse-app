import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cinemuse_app/core/services/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/core/services/streaming/sources/base_source.dart';
import 'package:cinemuse_app/core/services/media/tmdb_service.dart';
import 'package:cinemuse_app/core/services/anime/kitsu_mapping_service.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/streaming/models/streaming_exceptions.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';

class MockSource extends Mock implements BaseSource {}
class MockTmdbService extends Mock implements TmdbService {}
class MockKitsuMappingService extends Mock implements KitsuMappingService {}

// Register fallback for StreamSearchContext if needed (for any())
class FakeStreamSearchContext extends Fake implements StreamSearchContext {}

void main() {
  late UnifiedStreamResolver resolver;
  late MockSource mockSource;
  late MockTmdbService mockTmdb;
  late MockKitsuMappingService mockKitsu;

  setUpAll(() {
    registerFallbackValue(FakeStreamSearchContext());
    registerFallbackValue(StreamCandidate(title: '', infoHash: '', magnet: '', provider: ''));
  });

  setUp(() {
    mockSource = MockSource();
    mockTmdb = MockTmdbService();
    mockKitsu = MockKitsuMappingService();

    when(() => mockSource.name).thenReturn('MockSource');
    when(() => mockSource.supportedCategories).thenReturn({'movie', 'tv', 'anime'});

    when(() => mockKitsu.getMapping(
      tmdbId: any(named: 'tmdbId'),
      type: any(named: 'type'),
      season: any(named: 'season'),
      episode: any(named: 'episode'),
    )).thenAnswer((_) async => null);

    resolver = UnifiedStreamResolver(
      sources: [mockSource],
      tmdbService: mockTmdb,
      kitsuMappingService: mockKitsu,
      settings: const UserSettings(),
    );
  });

  group('UnifiedStreamResolver.searchStreams', () {
    test('Should aggregate and deduplicate streams from sources', () async {
      // Setup TMDB mock
      when(() => mockTmdb.getMediaDetails(any(), any())).thenAnswer((_) async => {
        'id': 123,
        'imdb_id': 'tt123',
        'title': 'Test Movie',
      });
      when(() => mockTmdb.getImdbId(any(), any())).thenAnswer((_) async => 'tt123');

      // Setup Source mock with duplicate hashes
      final c1 = StreamCandidate(title: 'Stream 1', infoHash: 'abc', magnet: 'm1', seeds: 10, provider: 'S1');
      final c2 = StreamCandidate(title: 'Stream 1 copy', infoHash: 'abc', magnet: 'm1', seeds: 5, provider: 'S1');
      final c3 = StreamCandidate(title: 'Stream 2', infoHash: 'def', magnet: 'm2', seeds: 2, provider: 'S1');
      
      when(() => mockSource.search(any())).thenAnswer((_) async => [c1, c2, c3]);

      final results = await resolver.searchStreams('123', 'movie');

      expect(results.length, equals(2), reason: 'Should deduplicate by infoHash');
      expect(results.any((c) => c.infoHash == 'abc'), isTrue);
    });

    test('Should handle source failures gracefully', () async {
       when(() => mockTmdb.getMediaDetails(any(), any())).thenAnswer((_) async => {
        'id': 123, 'imdb_id': 'tt123',
      });
      when(() => mockSource.search(any())).thenThrow(Exception('Source down'));

      expect(() => resolver.searchStreams('123', 'movie'), throwsA(isA<StreamingException>()));
    });

    test('Should throw NoProvidersEnabledException when sources list is empty', () async {
      final emptyResolver = UnifiedStreamResolver(
        sources: [],
        tmdbService: mockTmdb,
        kitsuMappingService: mockKitsu,
        settings: const UserSettings(),
      );

      expect(() => emptyResolver.searchStreams('123', 'movie'), throwsA(isA<NoProvidersEnabledException>()));
    });

    test('Should throw MediaDetailsResolutionException when details are null', () async {
      when(() => mockTmdb.getMediaDetails(any(), any())).thenAnswer((_) async => null);

      expect(() => resolver.searchStreams('123', 'movie'), throwsA(isA<MediaDetailsResolutionException>()));
    });

    test('Should throw ImdbIdResolutionException when IMDB ID is missing', () async {
      when(() => mockTmdb.getMediaDetails(any(), any())).thenAnswer((_) async => {
        'id': 123,
      });
      when(() => mockTmdb.getImdbId(any(), any())).thenAnswer((_) async => null);

      expect(() => resolver.searchStreams('123', 'movie'), throwsA(isA<ImdbIdResolutionException>()));
    });

    test('Should throw NoResultsFoundException when no streams are found', () async {
      when(() => mockTmdb.getMediaDetails(any(), any())).thenAnswer((_) async => {
        'id': 123, 'imdb_id': 'tt123',
      });
      when(() => mockSource.search(any())).thenAnswer((_) async => []);

      expect(() => resolver.searchStreams('123', 'movie'), throwsA(isA<NoResultsFoundException>()));
    });
  });

  group('UnifiedStreamResolver.resolveStream', () {
    test('Should return resolved stream directly if URL is present', () async {
      final candidate = StreamCandidate(
        title: 'Test', infoHash: 'abc', magnet: 'mag', seeds: 1, provider: 'S',
        url: 'https://direct-link.com',
      );

      final result = await resolver.resolveStream(candidate);

      expect(result?.url, equals('https://direct-link.com'));
      expect(result?.provider, equals('S'));
    });
  });
}
