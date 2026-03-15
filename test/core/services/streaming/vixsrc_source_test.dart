import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:cinemuse_app/core/services/streaming/sources/vixsrc_source.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_search_context.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_metadata.dart';

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
              var config = {
                "token": "test-token",
                "expires": "123456789"
              };
              var source = {
                url: "https://vix-cdn.com/embed/123"
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
#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080
1080p.m3u8
      ''';

      final mockHtmlResponse = MockResponse();
      when(() => mockHtmlResponse.statusCode).thenReturn(200);
      when(() => mockHtmlResponse.data).thenReturn(html);

      final mockPlaylistResponse = MockResponse();
      when(() => mockPlaylistResponse.statusCode).thenReturn(200);
      when(() => mockPlaylistResponse.data).thenReturn(playlistHeader);

      when(() => mockDio.get(
        'https://vixsrc.to/movie/123',
        options: any(named: 'options'),
      )).thenAnswer((_) async => mockHtmlResponse);

      when(() => mockDio.get(
        any(that: contains('vix-cdn.com')),
        options: any(named: 'options'),
      )).thenAnswer((_) async => mockPlaylistResponse);

      final results = await source.search(context);

      expect(results.length, 1);
      final candidate = results.first;
      expect(candidate.provider, 'VixSrc');
      expect(candidate.url, contains('token=test-token'));
      expect(candidate.url, contains('expires=123456789'));
      expect(candidate.url, contains('h=1'));
      expect(candidate.metadata?.languages, containsAll(['IT', 'EN']));
      expect(candidate.metadata?.video.resolution, VideoResolution.r1080p);
    });

    test('search should return empty if extraction fails', () async {
      final context = StreamSearchContext(
        tmdbId: '123',
        type: 'movie',
        title: 'Test Movie',
      );

      final mockResponse = MockResponse();
      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.data).thenReturn('<html>No tokens here</html>');

      when(() => mockDio.get(any(), options: any(named: 'options')))
          .thenAnswer((_) async => mockResponse);

      final results = await source.search(context);
      expect(results, isEmpty);
    });
  });
}
