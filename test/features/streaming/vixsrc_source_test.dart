import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/streaming/sources/vixsrc_source.dart';
import 'package:cinemuse_app/features/streaming/models/stream_search_context.dart';
import 'package:cinemuse_app/features/streaming/models/stream_metadata.dart';

class MockDio extends Mock implements Dio {}

class MockResponse extends Mock implements Response {}

void main() {
  late VixSrcSource source;
  late MockDio mockDio;

  setUp(() {
    mockDio = MockDio();
    source = VixSrcSource(mockDio);
  });

  group('VixSrcSource', () {
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
                url: 'https://vixsrc.to/playlist/123?b=1'
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
          'https://vixsrc.to/api/movie/123',
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => mockApiResponse);

      when(
        () => mockDio.get(
          'https://vixsrc.to/embed/123',
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => mockHtmlResponse);

      when(
        () => mockDio.get(
          any(that: contains('vixsrc.to/playlist')),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => mockPlaylistResponse);

      final results = await source.search(context);

      expect(results.length, 1);
      final candidate = results.first;
      expect(candidate.provider, 'VixSrc');
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
          'https://vixsrc.to/api/movie/123',
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => mockApiResponse);

      when(
        () => mockDio.get(
          'https://vixsrc.to/embed/123',
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
                url: 'https://vixsrc.to/playlist/456?b=1'
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
          'https://vixsrc.to/api/tv/456/1/1',
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => mockApiResponse);

      when(
        () => mockDio.get(
          'https://vixsrc.to/embed/456',
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => mockHtmlResponse);

      when(
        () => mockDio.get(
          any(that: contains('vixsrc.to/playlist')),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => mockPlaylistResponse);

      final results = await source.search(context);

      expect(results.length, 1);
      final candidate = results.first;
      expect(candidate.provider, 'VixSrc');
      expect(candidate.url, contains('.m3u8'));
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

  group('VixSrcSource.deleteStaleManifests (REV-32)', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('vixsrc_test_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('deletes old playlists and keeps recent ones', () async {
      final old = File('${dir.path}/vixsrc_1.m3u8')..writeAsStringSync('old');
      old.setLastModifiedSync(DateTime.now().subtract(const Duration(days: 2)));
      final recent = File('${dir.path}/vixsrc_2.m3u8')
        ..writeAsStringSync('new');

      await VixSrcSource.deleteStaleManifests(dir);

      expect(old.existsSync(), isFalse);
      expect(recent.existsSync(), isTrue);
    });
  });
}
