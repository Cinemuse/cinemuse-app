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

class MockSource extends Mock implements BaseSource {}
class MockDebridService extends Mock implements BaseDebridService {}
class MockTmdbService extends Mock implements TmdbService {}
class MockKitsuMappingService extends Mock implements KitsuMappingService {}
class FakeMediaContext extends Fake implements MediaContext {}

void main() {
  late UnifiedStreamResolver resolver;
  late MockSource mediafusionSource;
  late MockSource torrentioSource;
  late MockTmdbService mockTmdb;
  late MockKitsuMappingService mockKitsu;

  setUpAll(() {
    registerFallbackValue(FakeMediaContext());
    registerFallbackValue(StreamCandidate(title: '', infoHash: '', magnet: '', provider: ''));
  });

  setUp(() {
    mediafusionSource = MockSource();
    torrentioSource = MockSource();
    mockTmdb = MockTmdbService();
    mockKitsu = MockKitsuMappingService();

    when(() => mediafusionSource.name).thenReturn('Mediafusion');
    when(() => torrentioSource.name).thenReturn('Torrentio');

    resolver = UnifiedStreamResolver(
      sources: [torrentioSource, mediafusionSource],
      debridServices: [],
      tmdbService: mockTmdb,
      kitsuMappingService: mockKitsu,
    );

    // Default stub for kitsu mapping
    when(() => mockKitsu.getMapping(
          tmdbId: any(named: 'tmdbId'),
          type: any(named: 'type'),
          season: any(named: 'season'),
          episode: any(named: 'episode'),
        )).thenAnswer((_) async => null);
  });

  group('Mediafusion Integration Logic', () {
    test('Should skip Mediafusion when isAnime is true', () async {
      when(() => mockTmdb.getMediaDetails(any(), any())).thenAnswer((_) async => {
        'id': 1, 
        'imdb_id': 'tt1', 
        'genres': [{'name': 'Animation', 'id': 16}],
        'original_language': 'ja',
      });
      // Mock identifying as anime
      when(() => mockTmdb.getImdbId(any(), any())).thenAnswer((_) async => 'tt1');
      
      // Setup sources
      when(() => torrentioSource.search(any())).thenAnswer((_) async => [
        StreamCandidate(title: 'T1', infoHash: 'h1', magnet: 'm1', provider: 'Torrentio')
      ]);
      // Safety stub to prevent crash if logic fails
      when(() => mediafusionSource.search(any())).thenAnswer((_) async => []);
      
      final results = await resolver.searchStreams('1', 'movie');
      
      expect(results.length, equals(1));
      expect(results.first.provider, equals('Torrentio'));
      verifyNever(() => mediafusionSource.search(any()));
    });

    test('Should resolve Mediafusion stream immediately if URL is present', () async {
      final candidate = StreamCandidate(
        title: 'MF Stream',
        infoHash: '',
        magnet: '',
        provider: 'Mediafusion',
        url: 'https://direct.link/video.m3u8',
      );

      final resolved = await resolver.resolveStream(candidate);

      expect(resolved, isNotNull);
      expect(resolved!.url, equals('https://direct.link/video.m3u8'));
      expect(resolved.provider, equals('Mediafusion'));
    });

    test('Should deduplicate by URL when infoHash is missing', () async {
      when(() => mockTmdb.getMediaDetails(any(), any())).thenAnswer((_) async => {
        'id': 1, 'imdb_id': 'tt1'
      });
      when(() => mockTmdb.getImdbId(any(), any())).thenAnswer((_) async => 'tt1');

      final mf1 = StreamCandidate(title: 'Stream', infoHash: '', magnet: '', provider: 'Mediafusion', url: 'url1');
      final mf2 = StreamCandidate(title: 'Stream', infoHash: '', magnet: '', provider: 'Mediafusion', url: 'url1');
      
      when(() => torrentioSource.search(any())).thenAnswer((_) async => []);
      when(() => mediafusionSource.search(any())).thenAnswer((_) async => [mf1, mf2]);

      final results = await resolver.searchStreams('1', 'movie');

      expect(results.length, equals(1), reason: 'Should deduplicate by URL');
    });
  });
}
