import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:cinemuse_app/features/media/data/imdb_service.dart';
import 'package:cinemuse_app/features/media/domain/comment.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late ImdbService imdbService;

  setUp(() {
    mockDio = MockDio();
    imdbService = ImdbService(mockDio);
  });

  group('ImdbService', () {
    test('returns empty list if imdbId is empty', () async {
      final result = await imdbService.fetchReviews(imdbId: '');
      expect(result, isEmpty);
      verifyNever(() => mockDio.post<Map<String, dynamic>>(any(), data: any(named: 'data')));
    });

    test('successfully parses GraphQL reviews', () async {
      final mockResponse = {
        'data': {
          'title': {
            'reviews': {
              'total': 1,
              'edges': [
                {
                  'node': {
                    'id': 'rw12345',
                    'author': {'nickName': 'Cinephile99'},
                    'authorRating': 9,
                    'submissionDate': '2024-02-15',
                    'summary': {'originalText': 'Masterpiece &amp; must see'},
                    'text': {
                      'originalText': {
                        'plaidHtml': 'A truly incredible journey.<br><br>Highly recommended!'
                      }
                    },
                    'helpfulness': {'upVotes': 150, 'downVotes': 10},
                  }
                }
              ]
            }
          }
        }
      };

      when(
        () => mockDio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: mockResponse,
          statusCode: 200,
          requestOptions: RequestOptions(path: 'https://caching.graphql.imdb.com/'),
        ),
      );

      final reviews = await imdbService.fetchReviews(imdbId: 'tt0816692');

      expect(reviews.length, 1);
      final review = reviews.first;
      expect(review.id, 'imdb_rw12345');
      expect(review.author.username, 'Cinephile99');
      expect(review.title, 'Masterpiece & must see');
      expect(review.text, 'A truly incredible journey.\n\nHighly recommended!');
      expect(review.rating, 4.5);
      expect(review.likeCount, 150);
      expect(review.source, CommentSource.imdb);
      expect(review.createdAt, DateTime.parse('2024-02-15'));
    });

    test('supports page pagination via cursor caching', () async {
      final mockPage1 = {
        'data': {
          'title': {
            'reviews': {
              'pageInfo': {'hasNextPage': true, 'endCursor': 'cursor_123'},
              'edges': [
                {
                  'node': {
                    'id': 'p1',
                    'author': {'nickName': 'User1'},
                    'authorRating': 10,
                    'summary': {'originalText': 'Review 1'},
                    'text': {'originalText': 'Body 1'},
                  }
                }
              ]
            }
          }
        }
      };

      final mockPage2 = {
        'data': {
          'title': {
            'reviews': {
              'pageInfo': {'hasNextPage': false, 'endCursor': null},
              'edges': [
                {
                  'node': {
                    'id': 'p2',
                    'author': {'nickName': 'User2'},
                    'authorRating': 8,
                    'summary': {'originalText': 'Review 2'},
                    'text': {'originalText': 'Body 2'},
                  }
                }
              ]
            }
          }
        }
      };

      when(
        () => mockDio.post<dynamic>(
          any(),
          data: any(named: 'data', that: containsPair('query', contains(r'$first: Int!'))),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: mockPage1,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      when(
        () => mockDio.post<dynamic>(
          any(),
          data: any(named: 'data', that: containsPair('query', contains(r'$after: ID!'))),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: mockPage2,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      final page1Reviews = await imdbService.fetchReviews(imdbId: 'tt0816692', page: 1);
      expect(page1Reviews.length, 1);
      expect(page1Reviews.first.id, 'imdb_p1');
      expect(page1Reviews.first.rating, 5.0); // 10 / 2 = 5.0

      final page2Reviews = await imdbService.fetchReviews(imdbId: 'tt0816692', page: 2);
      expect(page2Reviews.length, 1);
      expect(page2Reviews.first.id, 'imdb_p2');
      expect(page2Reviews.first.rating, 4.0); // 8 / 2 = 4.0
    });

    test('gracefully handles network error and returns empty list', () async {
      when(
        () => mockDio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          error: 'Network timeout',
        ),
      );

      final reviews = await imdbService.fetchReviews(imdbId: 'tt0816692');
      expect(reviews, isEmpty);
    });
  });
}
