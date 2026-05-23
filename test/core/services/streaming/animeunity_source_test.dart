import 'package:cinemuse_app/core/services/anime/interfaces/anime_unity_mapping_provider.dart';
import 'package:cinemuse_app/core/services/anime/models/anime_unity_entry.dart';
import 'package:cinemuse_app/core/services/anime/models/kitsu_mapping.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:cinemuse_app/core/services/streaming/sources/animeunity_source.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_search_context.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_metadata.dart';

class MockDio extends Mock implements Dio {}
class MockAnimeUnityMappingProvider extends Mock implements AnimeUnityMappingProvider {}
class MockResponse extends Mock implements Response {}

void main() {
  late AnimeUnitySource source;
  late MockDio mockDio;
  late MockAnimeUnityMappingProvider mockMappingService;

  setUp(() {
    mockDio = MockDio();
    mockMappingService = MockAnimeUnityMappingProvider();
    source = AnimeUnitySource(mockDio, mockMappingService);
  });

  group('AnimeUnitySource', () {
    test('search should return streams when mapping and API succeed', () async {
      final context = StreamSearchContext(
        tmdbId: '123',
        type: 'tv',
        title: 'Test Anime',
        isAnime: true,
        episode: 1,
        season: 1,
        mapping: KitsuMapping(
          kitsuId: '12',
          absoluteEpisode: 1,
        ),
      );

      when(() => mockMappingService.getAnimeUnityIds('12'))
          .thenAnswer((_) async => [AnimeUnityEntry(id: 999, path: '/anime/999-test')]);

      // Mock info_api response
      final infoResponse = MockResponse();
      when(() => infoResponse.statusCode).thenReturn(200);
      when(() => infoResponse.data).thenReturn({
        'episodes': [
          {
            'id': 1000,
            'number': 1,
            'file_name': 'Test.S01E01.1080p.mkv',
          }
        ]
      });

      // Mock embed-url response
      final embedUrlResponse = MockResponse();
      when(() => embedUrlResponse.statusCode).thenReturn(200);
      when(() => embedUrlResponse.data).thenReturn('https://vixcloud.co/embed/1234');

      // Mock VixCloud HTML
      final htmlResponse = MockResponse();
      when(() => htmlResponse.statusCode).thenReturn(200);
      when(() => htmlResponse.data).thenReturn('''
        <script>
          window.masterPlaylistUrl = 'https://vixcloud.co/playlist/1234';
          var token = 'test-token';
          var expires = '123456';
          window.canPlayFHD = true;
          window.masterPlaylist = {
            url: 'https://vixcloud.co/playlist/1234',
            params: {
              token: 'test-token',
              expires: '123456'
            }
          };
        </script>
      ''');

      // Mock Playlist
      final playlistResponse = MockResponse();
      when(() => playlistResponse.statusCode).thenReturn(200);
      when(() => playlistResponse.data).thenReturn('''
#EXTM3U
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Italiano",LANGUAGE="it"
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="English",LANGUAGE="en"
      ''');

      when(() => mockDio.get(
        any(that: contains('info_api/999/1')),
        options: any(named: 'options'),
      )).thenAnswer((_) async => infoResponse);

      when(() => mockDio.get(
        any(that: contains('embed-url/1000')),
        options: any(named: 'options'),
      )).thenAnswer((_) async => embedUrlResponse);

      when(() => mockDio.get(
        'https://vixcloud.co/embed/1234',
        options: any(named: 'options'),
      )).thenAnswer((_) async => htmlResponse);

      when(() => mockDio.get(
        any(that: contains('.m3u8')),
        options: any(named: 'options'),
      )).thenAnswer((_) async => playlistResponse);

      final results = await source.search(context);

      expect(results.length, 1);
      final candidate = results.first;
      expect(candidate.provider, 'AnimeUnity');
      expect(candidate.title, contains('Ep.1'));
      expect(candidate.metadata?.languages, containsAll(['IT', 'EN']));
      expect(candidate.metadata?.video.resolution, VideoResolution.r1080p);
      expect(candidate.url, contains('token=test-token'));
      expect(candidate.url, contains('h=1'));
    });

    test('search should return empty if context is not anime', () async {
      final context = StreamSearchContext(
        tmdbId: '123',
        type: 'movie',
        title: 'Test Movie',
        isAnime: false,
      );

      final results = await source.search(context);
      expect(results, isEmpty);
      verifyNever(() => mockMappingService.getAnimeUnityIds(any()));
    });
  });
}
