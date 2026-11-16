import 'package:cinemuse_app/core/data/server_addresses_model.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cinemuse_app/features/media/data/series_reviews_service.dart';

class MockDio extends Mock implements Dio {}

ServerAddressesLoader _addressesWith(String? reviews) =>
    () async => ServerAddresses.fromRows([
      if (reviews != null)
        {
          'key': ServerAddress.reviews.key,
          'address': reviews,
          'display_name': 'ReviewSite',
        },
    ]);

void main() {
  late MockDio mockDio;
  late SeriesReviewsService service;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() {
    mockDio = MockDio();
    service = SeriesReviewsService(
      mockDio,
      _addressesWith('https://reviews.example/api/'),
    );
  });

  group('SeriesReviewsService', () {
    test('resolveSeasonId makes GET request and caches response', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          'https://reviews.example/api/show/1399/season/1',
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
          'https://reviews.example/api/show/1399/season/1',
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('resolveSeasonId returns null on error without throwing', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          'https://reviews.example/api/show/999/season/1',
          options: any(named: 'options'),
        ),
      ).thenThrow(DioException(requestOptions: RequestOptions(path: '')));

      final seasonId = await service.resolveSeasonId(999, 1);
      expect(seasonId, isNull);
    });

    test(
      'fetchEpisodeReviews includes required query params and headers',
      () async {
        when(
          () => mockDio.get<Map<String, dynamic>>(
            'https://reviews.example/api/show/1399/reviewspage_v3',
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
                },
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
            'https://reviews.example/api/show/1399/reviewspage_v3',
            queryParameters: {
              'sort_by': 'like_desc',
              'episode_number': 1,
              'include_episode_reviews': true,
              'season_id': 12345,
            },
            options: any(named: 'options'),
          ),
        ).called(1);
      },
    );

    group('the next batch of reviews', () {
      const showUrl = 'https://reviews.example/api/show/1399/reviewspage_v3';

      /// Answers each request with the next of [answers], and returns what
      /// was asked each time.
      List<Map<String, dynamic>> answerInTurn(
        List<Map<String, dynamic>> answers,
      ) {
        final asked = <Map<String, dynamic>>[];
        when(
          () => mockDio.get<Map<String, dynamic>>(
            showUrl,
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) async {
          asked.add(
            invocation.namedArguments[#queryParameters] as Map<String, dynamic>,
          );
          return Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 200,
            data: answers[asked.length - 1],
          );
        });
        return asked;
      }

      Map<String, dynamic> batch(Object? next, Object? secondaryNext) => {
        'items': [
          {'id': 1},
        ],
        'nextCursor': next,
        'secondaryNextCursor': secondaryNext,
      };

      test('sends back where the previous batch said it starts', () async {
        final asked = answerInTurn([
          batch(155, '2022-12-18 15:11:55'),
          batch(0, '2022-09-07 10:39:42'),
          batch(null, null),
        ]);

        await service.fetchShowReviews(showId: 1399);
        await service.fetchShowReviews(showId: 1399, page: 2);
        await service.fetchShowReviews(showId: 1399, page: 3);

        expect(asked, [
          {'sort_by': 'like_desc'},
          {
            'sort_by': 'like_desc',
            'cursor': 155,
            'secondary_cursor': '2022-12-18 15:11:55',
          },
          // Zero is a real position: the reviews with no likes.
          {
            'sort_by': 'like_desc',
            'cursor': 0,
            'secondary_cursor': '2022-09-07 10:39:42',
          },
        ]);
      });

      test('the end of the list asks nothing more', () async {
        final asked = answerInTurn([batch(null, null)]);

        await service.fetchShowReviews(showId: 1399);
        final next = await service.fetchShowReviews(showId: 1399, page: 2);

        expect(next, isEmpty);
        expect(asked, hasLength(1));
      });

      test('a show and its episode keep their own positions', () async {
        final asked = answerInTurn([
          batch(155, 'show position'),
          batch(81, 'episode position'),
          batch(null, null),
          batch(null, null),
        ]);

        await service.fetchShowReviews(showId: 1399);
        await service.fetchEpisodeReviews(
          showId: 1399,
          seasonNumber: 1,
          episodeNumber: 1,
          seasonId: 12345,
        );
        await service.fetchShowReviews(showId: 1399, page: 2);
        await service.fetchEpisodeReviews(
          showId: 1399,
          seasonNumber: 1,
          episodeNumber: 1,
          seasonId: 12345,
          page: 2,
        );

        expect(asked[2]['cursor'], 155);
        expect(asked[3]['cursor'], 81);
      });

      test('page 1 asked again starts over', () async {
        final asked = answerInTurn([
          batch(155, 'first'),
          batch(111, 'second'),
          batch(155, 'first'),
          batch(111, 'second'),
        ]);

        await service.fetchShowReviews(showId: 1399);
        await service.fetchShowReviews(showId: 1399, page: 2);
        await service.fetchShowReviews(showId: 1399);
        await service.fetchShowReviews(showId: 1399, page: 2);

        expect(asked[2], {'sort_by': 'like_desc'});
        expect(asked[3]['cursor'], 155);
      });
    });

    test('fetchReviewComments returns list of comments', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          'https://reviews.example/api/review/101/comments',
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: {
            'reviewComments': [
              {'id': 1, 'author': 'User2', 'commentText': 'Agreed!'},
            ],
          },
        ),
      );

      final replies = await service.fetchReviewComments('101');
      expect(replies.length, 1);
      expect(replies.first['commentText'], 'Agreed!');
    });

    // REV-189: show reviews and replies returned {} / [] when offline, so
    // "offline" looked like "no reviews".
    test('offline requests throw a NetworkFailure', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        service.fetchShowReviews(showId: 1399),
        throwsA(isA<NetworkFailure>()),
      );
      await expectLater(
        service.fetchReviewComments('101'),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test("the API is asked with the word made of the site's name", () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: {'reviewComments': []},
        ),
      );

      await service.fetchReviewComments('101');

      final options =
          verify(
                () => mockDio.get<Map<String, dynamic>>(
                  any(),
                  options: captureAny(named: 'options'),
                ),
              ).captured.single
              as Options;
      expect(options.headers, {'X-Requested-With': 'reviewsite_vercel'});
    });

    test('no address in the list: throws, asks nothing', () async {
      service = SeriesReviewsService(mockDio, _addressesWith(null));

      await expectLater(
        service.fetchShowReviews(showId: 1399),
        throwsA(isA<NotFoundFailure>()),
      );
      verifyZeroInteractions(mockDio);
    });
  });
}
