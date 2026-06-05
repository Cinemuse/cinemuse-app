import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/features/media/data/tvtime_service.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

class FakeRequestOptions extends Fake implements RequestOptions {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRequestOptions());
    registerFallbackValue(Options());
  });

  group('TvTimeService Unit Tests', () {
    late TvTimeService service;
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
      service = TvTimeService(mockDio);
    });

    test('resolveSeriesUuid parses sidecar response correctly', () async {
      when(() => mockDio.get<dynamic>(any())).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: {
            'status': 'success',
            'data': {'uuid': 'test-uuid-123'},
          },
        ),
      );

      final uuid = await service.resolveSeriesUuid(12345);
      expect(uuid, 'test-uuid-123');
    });

    test('resolveMovieUuid parses html anchor correctly', () async {
      const html = '''
        <html><body>
          <a class="something" href="/movie/11111111-2222-3333-4444-555555555555">Movie</a>
        </body></html>
      ''';

      when(
        () => mockDio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer(
        (_) async => Response<String>(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: html,
        ),
      );

      final uuid = await service.resolveMovieUuid('tt1234567');
      expect(uuid, '11111111-2222-3333-4444-555555555555');
    });

    test('resolveEpisodeUuid parses html show page correctly', () async {
      const html = '''
        <html><body>
          <a class="episodes" href="https://app.tvtime.com/show/uuid-here/episode/11111111-2222-3333-4444-555555555555">
            <div>S01 | E01</div>
          </a>
        </body></html>
      ''';

      when(
        () => mockDio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer(
        (_) async => Response<String>(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: html,
        ),
      );

      final uuid = await service.resolveEpisodeUuid(
        81189,
        season: 1,
        episode: 1,
      );
      expect(uuid, '11111111-2222-3333-4444-555555555555');
    });

    test('fetchSeriesComments resolves uuid and fetches comments', () async {
      // First call is resolve UUID
      // Second call is fetch comments
      int callCount = 0;
      when(() => mockDio.get<dynamic>(any())).thenAnswer((_) async {
        if (callCount == 0) {
          callCount++;
          return Response(
            requestOptions: RequestOptions(path: ''),
            data: {
              'status': 'success',
              'data': {'uuid': 'test-series-uuid'},
            },
          );
        } else {
          return Response(
            requestOptions: RequestOptions(path: ''),
            data: {
              'data': [
                {
                  'uuid': 'comment-uuid-1',
                  'text': 'Great show!',
                  'user': {'name': 'User A'},
                },
              ],
            },
          );
        }
      });

      final comments = await service.fetchSeriesComments(12345);
      expect(comments.length, 1);
      expect(comments.first.text, 'Great show!');
      expect(comments.first.user.name, 'User A');
    });
  });
}
