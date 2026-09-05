import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cinemuse_app/features/media/data/serializd_service.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late SerializdService service;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() {
    mockDio = MockDio();
    service = SerializdService(mockDio);
  });

  group('SerializdService', () {
    test('resolveSeasonId makes GET request and caches response', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          'https://serializd.onrender.com/api/show/1399/season/1',
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: {'seasonId': 12345},
        ),
      );

      final seasonId = await service.resolveSeasonId(1399, 1);
      expect(seasonId, 12345);

      // Verify cached on second call
      final cachedSeasonId = await service.resolveSeasonId(1399, 1);
      expect(cachedSeasonId, 12345);
      verify(
        () => mockDio.get<Map<String, dynamic>>(
          'https://serializd.onrender.com/api/show/1399/season/1',
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('resolveSeasonId returns null on error without throwing', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          'https://serializd.onrender.com/api/show/999/season/1',
          options: any(named: 'options'),
        ),
      ).thenThrow(DioException(requestOptions: RequestOptions(path: '')));

      final seasonId = await service.resolveSeasonId(999, 1);
      expect(seasonId, isNull);
    });

    test('fetchEpisodeReviews includes required query params and headers', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          'https://serializd.onrender.com/api/show/1399/reviewspage_v3',
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: {
            'reviews': [
              {
                'id': 101,
                'author': 'Tester',
                'reviewText': 'Great episode!',
                'rating': 4.5,
              }
            ],
          },
        ),
      );

      final result = await service.fetchEpisodeReviews(
        showId: 1399,
        seasonNumber: 1,
        episodeNumber: 1,
        seasonId: 12345,
      );

      expect(result['reviews'], isNotEmpty);
      verify(
        () => mockDio.get<Map<String, dynamic>>(
          'https://serializd.onrender.com/api/show/1399/reviewspage_v3',
          queryParameters: {
            'sort_by': 'like_desc',
            'episode_number': 1,
            'include_episode_reviews': true,
            'season_id': 12345,
            'page': 1,
          },
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('fetchReviewComments returns list of comments', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          'https://serializd.onrender.com/api/review/101/comments',
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: {
            'reviewComments': [
              {
                'id': 1,
                'author': 'User2',
                'commentText': 'Agreed!',
              }
            ],
          },
        ),
      );

      final replies = await service.fetchReviewComments('101');
      expect(replies.length, 1);
      expect(replies.first['commentText'], 'Agreed!');
    });
  });
}
