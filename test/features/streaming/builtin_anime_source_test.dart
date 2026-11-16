import 'package:cinemuse_app/core/data/server_addresses_model.dart';
import 'package:cinemuse_app/features/streaming/anime/interfaces/builtin_anime_lookup.dart';
import 'package:cinemuse_app/features/streaming/anime/models/builtin_anime_entry.dart';
import 'package:cinemuse_app/features/streaming/anime/models/anime_match.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:cinemuse_app/features/streaming/sources/builtin_anime_source.dart';
import 'package:cinemuse_app/features/streaming/models/stream_search_context.dart';
import 'package:cinemuse_app/features/streaming/models/stream_metadata.dart';

class MockDio extends Mock implements Dio {}

class MockBuiltInAnimeLookup extends Mock implements BuiltInAnimeLookup {}

class MockResponse extends Mock implements Response {}

BuiltInAnimeEntries _entryAt(String siteAddress) => BuiltInAnimeEntries(
  siteAddress: siteAddress,
  entries: [BuiltInAnimeEntry(id: 999, path: '/anime/999-test')],
);

void main() {
  late BuiltInAnimeSource source;
  late MockDio mockDio;
  late MockBuiltInAnimeLookup mockMappingService;

  setUp(() {
    mockDio = MockDio();
    mockMappingService = MockBuiltInAnimeLookup();
    source = BuiltInAnimeSource(
      mockDio,
      mockMappingService,
      () async => ServerAddresses.fromRows([
        {
          'key': ServerAddress.animeSite.key,
          'address': 'https://anime.example',
        },
      ]),
      name: 'Anime Site',
    );
  });

  group('BuiltInAnimeSource', () {
    test('no address in the list: finds nothing (STR-08)', () async {
      source = BuiltInAnimeSource(
        mockDio,
        mockMappingService,
        () async => ServerAddresses.empty,
        name: 'Anime Site',
      );

      final results = await source.search(
        StreamSearchContext(
          tmdbId: '123',
          type: 'tv',
          title: 'Test Anime',
          isAnime: true,
          episode: 1,
          mapping: AnimeMatch(anilistId: 7, kitsuId: '12', absoluteEpisode: 1),
        ),
      );

      expect(results, isEmpty);
      verifyZeroInteractions(mockDio);
      verifyZeroInteractions(mockMappingService);
    });

    test('search should return streams when mapping and API succeed', () async {
      final context = StreamSearchContext(
        tmdbId: '123',
        type: 'tv',
        title: 'Test Anime',
        isAnime: true,
        episode: 1,
        season: 1,
        mapping: AnimeMatch(anilistId: 7, kitsuId: '12', absoluteEpisode: 1),
      );

      when(
        () => mockMappingService.findEntries(context.mapping!),
      ).thenAnswer((_) async => _entryAt('https://anime.example'));

      // Mock info_api response
      final infoResponse = MockResponse();
      when(() => infoResponse.statusCode).thenReturn(200);
      when(() => infoResponse.data).thenReturn({
        'episodes': [
          {'id': 1000, 'number': 1, 'file_name': 'Test.S01E01.1920x1080.mkv'},
        ],
      });

      // Mock embed-url response
      final embedUrlResponse = MockResponse();
      when(() => embedUrlResponse.statusCode).thenReturn(200);
      when(
        () => embedUrlResponse.data,
      ).thenReturn('https://videos.example/embed/1234');

      // Mock video page HTML
      final htmlResponse = MockResponse();
      when(() => htmlResponse.statusCode).thenReturn(200);
      when(() => htmlResponse.data).thenReturn('''
        <script>
          window.masterPlaylistUrl = 'https://videos.example/playlist/1234';
          var token = 'test-token';
          var expires = '123456';
          window.canPlayFHD = true;
          window.masterPlaylist = {
            url: 'https://videos.example/playlist/1234',
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

      when(
        () => mockDio.get(
          any(that: contains('info_api/999/1')),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => infoResponse);

      when(
        () => mockDio.get(
          any(that: contains('embed-url/1000')),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => embedUrlResponse);

      when(
        () => mockDio.get(
          'https://videos.example/embed/1234',
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => htmlResponse);

      when(
        () => mockDio.get(
          any(that: contains('.m3u8')),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => playlistResponse);

      final results = await source.search(context);

      expect(results.length, 1);
      final candidate = results.first;
      expect(candidate.provider, 'Anime Site');
      expect(candidate.title, contains('Ep.1'));
      expect(candidate.metadata?.languages, containsAll(['ITA', 'ENG']));
      expect(candidate.metadata?.video.resolution, VideoResolution.r1080p);
      expect(candidate.url, contains('token=test-token'));
      expect(candidate.url, contains('h=1'));
    });

    group('a playlist that names no sound language', () {
      Future<List<String>?> languagesOf(String path) async {
        final context = StreamSearchContext(
          tmdbId: '123',
          type: 'tv',
          title: 'Test Anime',
          isAnime: true,
          episode: 1,
          mapping: AnimeMatch(anilistId: 7, kitsuId: '12', absoluteEpisode: 1),
        );
        when(() => mockMappingService.findEntries(context.mapping!)).thenAnswer(
          (_) async => BuiltInAnimeEntries(
            siteAddress: 'https://anime.example',
            entries: [BuiltInAnimeEntry(id: 999, path: path)],
          ),
        );
        MockResponse answer(Object data) {
          final response = MockResponse();
          when(() => response.statusCode).thenReturn(200);
          when(() => response.data).thenReturn(data);
          return response;
        }

        final info = answer({
          'episodes': [
            {'id': 1000, 'number': 1, 'file_name': 'Test.S01E01.1080p.mkv'},
          ],
        });
        final embed = answer('https://videos.example/embed/1234');
        final page = answer('''
          <script>
            window.masterPlaylist = {
              url: 'https://videos.example/playlist/1234',
              params: { token: 'test-token', expires: '123456' }
            };
          </script>
        ''');
        final playlist = answer('''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1200000,RESOLUTION=1920x1080
https://videos.example/playlist/1234/1080p.m3u8
        ''');
        when(
          () => mockDio.get(any(), options: any(named: 'options')),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;
          if (url.contains('info_api')) return info;
          if (url.contains('embed-url')) return embed;
          if (url.contains('.m3u8')) return playlist;
          return page;
        });

        final results = await source.search(context);
        expect(results, hasLength(1));
        return results.single.metadata?.languages;
      }

      test('the Italian dub entry is ITA', () async {
        expect(await languagesOf('/anime/4852-frieren-ita'), ['ITA']);
      });

      test('the subtitled entry is JPN', () async {
        expect(await languagesOf('/anime/4851-frieren'), ['JPN']);
      });
    });

    test('a site that moved: the episodes come from its new address', () async {
      final context = StreamSearchContext(
        tmdbId: '123',
        type: 'tv',
        title: 'Test Anime',
        isAnime: true,
        episode: 1,
        season: 1,
        mapping: AnimeMatch(anilistId: 7, kitsuId: '12', absoluteEpisode: 1),
      );
      when(
        () => mockMappingService.findEntries(context.mapping!),
      ).thenAnswer((_) async => _entryAt('https://anime-new.example'));

      final infoResponse = MockResponse();
      when(() => infoResponse.statusCode).thenReturn(200);
      when(() => infoResponse.data).thenReturn({
        'episodes': [
          {'id': 1000, 'number': 1, 'file_name': 'Test.S01E01.mkv'},
        ],
      });
      when(
        () => mockDio.get(
          'https://anime-new.example/info_api/999/1?start_range=1&end_range=1',
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => infoResponse);

      final embedResponse = MockResponse();
      when(() => embedResponse.statusCode).thenReturn(200);
      when(() => embedResponse.data).thenReturn('not an address');
      when(() => embedResponse.headers).thenReturn(Headers());
      when(
        () => mockDio.get(
          'https://anime-new.example/embed-url/1000',
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => embedResponse);

      await source.search(context);

      verify(
        () => mockDio.get(
          'https://anime-new.example/embed-url/1000',
          options: any(named: 'options'),
        ),
      ).called(1);
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
      verifyZeroInteractions(mockMappingService);
    });

    test(
      'never plays another episode than the one asked for (REV-241)',
      () async {
        final context = StreamSearchContext(
          tmdbId: '123',
          type: 'tv',
          title: 'Test Anime',
          isAnime: true,
          episode: 3,
          season: 1,
          mapping: AnimeMatch(anilistId: 7, kitsuId: '12', absoluteEpisode: 3),
        );
        when(
          () => mockMappingService.findEntries(context.mapping!),
        ).thenAnswer((_) async => _entryAt('https://anime.example'));
        final infoResponse = MockResponse();
        when(() => infoResponse.statusCode).thenReturn(200);
        when(() => infoResponse.data).thenReturn({
          'episodes': [
            {'id': 1000, 'number': '2', 'file_name': 'Test.S01E02.mkv'},
          ],
        });
        when(
          () => mockDio.get(
            any(that: contains('info_api/999/1')),
            options: any(named: 'options'),
          ),
        ).thenAnswer((_) async => infoResponse);

        final results = await source.search(context);

        expect(results, isEmpty);
        verifyNever(
          () => mockDio.get(
            any(that: contains('embed-url')),
            options: any(named: 'options'),
          ),
        );
      },
    );
  });
}
