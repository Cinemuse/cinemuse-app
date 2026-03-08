import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cinemuse_app/core/services/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/core/services/streaming/sources/base_source.dart';
import 'package:cinemuse_app/core/services/streaming/debrid/base_debrid_service.dart';
import 'package:cinemuse_app/core/services/media/tmdb_service.dart';
import 'package:cinemuse_app/core/services/anime/kitsu_mapping_service.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/streaming/models/media_context.dart';
import 'package:cinemuse_app/core/services/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/core/services/streaming/models/streaming_exceptions.dart';

class MockSource extends Mock implements BaseSource {}

class MockDebridService extends Mock implements BaseDebridService {}

class MockTmdbService extends Mock implements TmdbService {}
class MockKitsuMappingService extends Mock implements KitsuMappingService {}

// Register fallback for MediaContext if needed (for any())
class FakeMediaContext extends Fake implements MediaContext {}

void main() {
  late UnifiedStreamResolver resolver;
  late MockSource mockSource;
  late MockDebridService mockDebrid;
  late MockTmdbService mockTmdb;
  late MockKitsuMappingService mockKitsu;

  setUpAll(() {
    registerFallbackValue(FakeMediaContext());
    registerFallbackValue(StreamCandidate(title: '', infoHash: '', magnet: '', provider: ''));
  });

  setUp(() {
    mockSource = MockSource();
    mockDebrid = MockDebridService();
    mockTmdb = MockTmdbService();
    mockKitsu = MockKitsuMappingService();

    when(() => mockSource.name).thenReturn('MockSource');
    when(() => mockDebrid.name).thenReturn('MockDebrid');

    resolver = UnifiedStreamResolver(
      sources: [mockSource],
      debridServices: [mockDebrid],
      tmdbService: mockTmdb,
      kitsuMappingService: mockKitsu,
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

      // Setup Debrid mock
      when(() => mockDebrid.checkAvailability(any())).thenAnswer((_) async => {
        'abc': true,
        'def': false,
      });

      final results = await resolver.searchStreams('123', 'movie');

      expect(results.length, equals(2), reason: 'Should deduplicate by infoHash');
      expect(results.any((c) => c.infoHash == 'abc'), isTrue);
      expect(results.firstWhere((c) => c.infoHash == 'abc').isCached, isTrue);
      expect(results.firstWhere((c) => c.infoHash == 'def').isCached, isFalse);
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
        debridServices: [mockDebrid],
        tmdbService: mockTmdb,
        kitsuMappingService: mockKitsu,
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
    test('Should prioritize cached debrid services', () async {
      final mockDebrid1 = MockDebridService();
      when(() => mockDebrid1.name).thenReturn('D1');
      final mockDebrid2 = MockDebridService();
      when(() => mockDebrid2.name).thenReturn('D2');

      final resolverWithMany = UnifiedStreamResolver(
        sources: [mockSource],
        debridServices: [mockDebrid1, mockDebrid2],
        tmdbService: mockTmdb,
        kitsuMappingService: mockKitsu,
      );

      final candidate = StreamCandidate(
        title: 'Test', infoHash: 'abc', magnet: 'mag', seeds: 1, provider: 'S',
        cachedOn: {'D1': false, 'D2': true}, // Only D2 has it
      );

      when(() => mockDebrid1.resolve(
        any(), 
        season: any(named: 'season'), 
        episode: any(named: 'episode'), 
        fileId: any(named: 'fileId'),
      )).thenAnswer((_) async => ResolvedStream(url: 'url1', provider: 'D1', candidate: candidate));

      when(() => mockDebrid2.resolve(
        any(), 
        season: any(named: 'season'), 
        episode: any(named: 'episode'), 
        fileId: any(named: 'fileId'),
      )).thenAnswer((_) async => ResolvedStream(url: 'url2', provider: 'D2', candidate: candidate));

      final result = await resolverWithMany.resolveStream(candidate);

      expect(result?.url, equals('url2'), reason: 'Should pick D2 because it is cached there');
    });
  });
}
