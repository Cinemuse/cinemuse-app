import 'dart:io';
import 'package:cinemuse_app/core/data/server_addresses_model.dart';
import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:cinemuse_app/core/network/retry_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/streaming/sources/builtin_movie_source.dart';
import 'package:cinemuse_app/features/streaming/models/stream_search_context.dart';
import 'package:cinemuse_app/features/streaming/models/stream_metadata.dart';

class MockDio extends Mock implements Dio {}

class MockResponse extends Mock implements Response {}

ServerAddressesLoader _sitesWith(String? movieSite) =>
    () async => ServerAddresses.fromRows([
      if (movieSite != null)
        {'key': ServerAddress.movieSite.key, 'address': movieSite},
    ]);

Response<dynamic> _home({String? forwardedTo}) => Response<dynamic>(
  requestOptions: RequestOptions(),
  statusCode: 200,
  data: '<html>',
  redirects: [
    if (forwardedTo != null) RedirectRecord(302, 'GET', Uri.parse(forwardedTo)),
  ],
);

void main() {
  late BuiltInMovieSource source;
  late MockDio mockDio;

  setUp(() {
    mockDio = MockDio();
    source = BuiltInMovieSource(
      mockDio,
      _sitesWith('https://movies.example'),
      name: 'Movie Site',
    );
    when(
      () => mockDio.get(
        'https://movies.example/',
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => _home());
  });

  group('BuiltInMovieSource', () {
    test('search should construct correct URL and extract tokens', () async {
      final context = StreamSearchContext(
        tmdbId: '123',
        type: 'movie',
        title: 'Test Movie',
      );

      final html = '''
        <html>
          <body>
            <script>
              window.masterPlaylist = {
                params: {
                  'token': 'test-token',
                  'expires': '123456789'
                },
                url: 'https://movies.example/playlist/123?b=1'
              };
            </script>
          </body>
        </html>
      ''';

      final playlistHeader = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Italian",LANGUAGE="it",AUTOSELECT=YES,DEFAULT=YES,URI="it.m3u8"
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="English",LANGUAGE="en",AUTOSELECT=YES,DEFAULT=NO,URI="en.m3u8"
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="Italian",LANGUAGE="ita",URI="it.vtt"
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="English",LANGUAGE="eng",URI="en.vtt"
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="Arabic",LANGUAGE="ara",URI="ara.vtt"
#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080
1080p.m3u8
      ''';

      final mockApiResponse = MockResponse();
      when(() => mockApiResponse.statusCode).thenReturn(200);
      when(() => mockApiResponse.data).thenReturn({'src': '/embed/123'});

      final mockHtmlResponse = MockResponse();
      when(() => mockHtmlResponse.statusCode).thenReturn(200);
      when(() => mockHtmlResponse.data).thenReturn(html);

      final mockPlaylistResponse = MockResponse();
      when(() => mockPlaylistResponse.statusCode).thenReturn(200);
      when(() => mockPlaylistResponse.data).thenReturn(playlistHeader);

      when(
        () => mockDio.get(
          'https://movies.example/api/movie/123',
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => mockApiResponse);

      when(
        () => mockDio.get(
          'https://movies.example/embed/123',
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => mockHtmlResponse);

      when(
        () => mockDio.get(
          any(that: contains('movies.example/playlist')),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => mockPlaylistResponse);

      final results = await source.search(context);

      expect(results.length, 1);
      final candidate = results.first;
      expect(candidate.provider, 'Movie Site');
      expect(candidate.url, contains('.m3u8'));
      expect(candidate.metadata?.languages, ['ITA', 'ENG']);
      expect(candidate.metadata?.video.resolution, VideoResolution.r1080p);

      // Verify the generated temp file contains preferred subtitles but excludes unneeded ones
      final savedManifest = await File(candidate.url!).readAsString();
      expect(savedManifest, contains('LANGUAGE="ita"'));
      expect(savedManifest, contains('LANGUAGE="eng"'));
      expect(savedManifest, isNot(contains('LANGUAGE="ara"')));

      // Verify unprobed subtitles are preserved as on-demand subtitles
      final onDemand =
          candidate.metadata?.custom?['onDemandSubtitles']
              as List<Map<String, String>>?;
      expect(onDemand, isNotNull);
      expect(onDemand!.any((s) => s['language'] == 'ara'), isTrue);
    });

    test('search should return empty if extraction fails', () async {
      final context = StreamSearchContext(
        tmdbId: '123',
        type: 'movie',
        title: 'Test Movie',
      );

      final mockApiResponse = MockResponse();
      when(() => mockApiResponse.statusCode).thenReturn(200);
      when(() => mockApiResponse.data).thenReturn({'src': '/embed/123'});

      final mockHtmlResponse = MockResponse();
      when(() => mockHtmlResponse.statusCode).thenReturn(200);
      when(
        () => mockHtmlResponse.data,
      ).thenReturn('<html>No tokens here</html>');

      when(
        () => mockDio.get(
          'https://movies.example/api/movie/123',
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => mockApiResponse);

      when(
        () => mockDio.get(
          'https://movies.example/embed/123',
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => mockHtmlResponse);

      final results = await source.search(context);
      expect(results, isEmpty);
    });

    test('search should construct correct URL for series type', () async {
      final context = StreamSearchContext(
        tmdbId: '456',
        type: 'series',
        title: 'The Boys',
        season: 1,
        episode: 1,
      );

      final html = '''
        <html>
          <body>
            <script>
              window.masterPlaylist = {
                params: {
                  'token': 'series-token',
                  'expires': '987654321'
                },
                url: 'https://movies.example/playlist/456?b=1'
              };
            </script>
          </body>
        </html>
      ''';

      final mockApiResponse = MockResponse();
      when(() => mockApiResponse.statusCode).thenReturn(200);
      when(() => mockApiResponse.data).thenReturn({'src': '/embed/456'});

      final mockHtmlResponse = MockResponse();
      when(() => mockHtmlResponse.statusCode).thenReturn(200);
      when(() => mockHtmlResponse.data).thenReturn(html);

      final mockPlaylistResponse = MockResponse();
      when(() => mockPlaylistResponse.statusCode).thenReturn(200);
      when(() => mockPlaylistResponse.data).thenReturn(
        '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080\n1080p.m3u8',
      );

      when(
        () => mockDio.get(
          'https://movies.example/api/tv/456/1/1',
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => mockApiResponse);

      when(
        () => mockDio.get(
          'https://movies.example/embed/456',
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => mockHtmlResponse);

      when(
        () => mockDio.get(
          any(that: contains('movies.example/playlist')),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => mockPlaylistResponse);

      final results = await source.search(context);

      expect(results.length, 1);
      final candidate = results.first;
      expect(candidate.provider, 'Movie Site');
      expect(candidate.url, contains('.m3u8'));
    });
  });

  group('BuiltInMovieSource address (STR-08)', () {
    final context = StreamSearchContext(
      tmdbId: '1',
      type: 'movie',
      title: 'Test Movie',
    );

    test('uses the address from the server list', () async {
      when(
        () => mockDio.get(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => _home());
      source = BuiltInMovieSource(
        mockDio,
        _sitesWith('https://movies-moved.example/'),
        name: 'Movie Site',
      );

      await source.search(context);

      verify(
        () => mockDio.get(
          'https://movies-moved.example/api/movie/1',
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('no address in the list: finds nothing, asks no site', () async {
      AppLogger.clearRecent();
      source = BuiltInMovieSource(
        mockDio,
        _sitesWith(null),
        name: 'Movie Site',
      );

      expect(await source.search(context), isEmpty);
      verifyZeroInteractions(mockDio);
      expect(
        AppLogger.recent.map((e) => e.message),
        contains('No movie site address in the site list'),
      );
    });
  });

  group('a site that moved', () {
    final context = StreamSearchContext(
      tmdbId: '1',
      type: 'movie',
      title: 'Test Movie',
    );
    const page = '''
      <script>
        window.masterPlaylist = {
          params: {'token': 'tok', 'expires': '1'},
          url: 'https://videos.example/playlist/1?b=1'
        };
      </script>
    ''';

    void stubSiteAt(String address) {
      final api = MockResponse();
      when(() => api.statusCode).thenReturn(200);
      when(() => api.data).thenReturn({'src': '/embed/1'});
      when(
        () =>
            mockDio.get('$address/api/movie/1', options: any(named: 'options')),
      ).thenAnswer((_) async => api);

      final video = MockResponse();
      when(() => video.statusCode).thenReturn(200);
      when(() => video.data).thenReturn(page);
      when(
        () => mockDio.get('$address/embed/1', options: any(named: 'options')),
      ).thenAnswer((_) async => video);

      // The playlist isn't needed: without it the untrimmed one plays.
      when(
        () => mockDio.get(
          any(that: contains('videos.example')),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.unknown,
        ),
      );
    }

    test('the whole visit uses where the home page landed', () async {
      when(
        () => mockDio.get(
          'https://movies.example/',
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => _home(forwardedTo: 'https://movies-new.example/'),
      );
      stubSiteAt('https://movies-new.example');

      final results = await source.search(context);

      expect(results, hasLength(1));
      // The video server is told the new address too.
      expect(results.single.headers, {
        'Referer': 'https://movies-new.example/movie/1',
        'Origin': 'https://movies-new.example',
        'User-Agent': browserUserAgent,
      });
      verifyNever(
        () => mockDio.get(
          'https://movies.example/api/movie/1',
          options: any(named: 'options'),
        ),
      );
    });

    test('a home page that fails: the search goes on at the listed address, '
        'after one try', () async {
      when(
        () => mockDio.get(
          'https://movies.example/',
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.connectionTimeout,
        ),
      );
      stubSiteAt('https://movies.example');

      expect(await source.search(context), hasLength(1));

      final options =
          verify(
                () => mockDio.get(
                  'https://movies.example/',
                  options: captureAny(named: 'options'),
                ),
              ).captured.single
              as Options;
      expect(options.extra?[RetryInterceptor.skipRetryKey], isTrue);
    });
  });

  test('a failed search is logged, not silent (REV-30)', () async {
    AppLogger.clearRecent();
    when(() => mockDio.get(any(), options: any(named: 'options'))).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/api/movie/1'),
        type: DioExceptionType.connectionError,
      ),
    );

    final results = await source.search(
      StreamSearchContext(tmdbId: '1', type: 'movie', title: 'Test Movie'),
    );

    expect(results, isEmpty);
    expect(
      AppLogger.recent.map((e) => e.message),
      contains(startsWith('Search failed for /movie/1')),
    );
  });

  group('BuiltInMovieSource.deleteStaleManifests (REV-32)', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('movie_test_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('deletes old playlists and keeps recent ones', () async {
      final old = File('${dir.path}/movie_1.m3u8')..writeAsStringSync('old');
      old.setLastModifiedSync(DateTime.now().subtract(const Duration(days: 2)));
      final recent = File('${dir.path}/movie_2.m3u8')..writeAsStringSync('new');

      await BuiltInMovieSource.deleteStaleManifests(dir);

      expect(old.existsSync(), isFalse);
      expect(recent.existsSync(), isTrue);
    });
  });
}
