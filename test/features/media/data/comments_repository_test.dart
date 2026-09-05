import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cinemuse_app/features/media/data/comments_repository_impl.dart';
import 'package:cinemuse_app/features/media/data/letterboxd_service.dart';
import 'package:cinemuse_app/features/media/data/serializd_service.dart';
import 'package:cinemuse_app/features/media/domain/comment.dart';
import 'package:cinemuse_app/features/media/domain/comments_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';

class MockSerializdService extends Mock implements SerializdService {}
class MockLetterboxdService extends Mock implements LetterboxdService {}

void main() {
  late MockSerializdService mockSerializd;
  late MockLetterboxdService mockLetterboxd;
  late CommentsRepositoryImpl repository;

  setUp(() {
    mockSerializd = MockSerializdService();
    mockLetterboxd = MockLetterboxdService();
    repository = CommentsRepositoryImpl(
      mockSerializd,
      mockLetterboxd,
    );
  });

  group('CommentsRepositoryImpl', () {
    test('fetchComments with EpisodeCommentsRequest maps Serializd reviews correctly', () async {
      when(
        () => mockSerializd.fetchEpisodeReviews(
          showId: 1399,
          seasonNumber: 1,
          episodeNumber: 1,
          seasonId: null,
          page: any(named: 'page'),
        ),
      ).thenAnswer(
        (_) async => {
          'reviews': [
            {
              'id': 1001,
              'author': 'john_doe',
              'authorImageUrl': 'https://example.com/avatar.jpg',
              'reviewText': 'Incredible pilot episode!',
              'rating': 5,
              'numLikes': 42,
              'numComments': 3,
              'containsSpoiler': true,
              'dateAdded': '2024-01-01T12:00:00Z',
            },
          ],
        },
      );

      final comments = await repository.fetchComments(
        const EpisodeCommentsRequest(
          tmdbShowId: 1399,
          seasonNumber: 1,
          episodeNumber: 1,
        ),
      );

      expect(comments.length, 1);
      final comment = comments.first;
      expect(comment.id, '1001');
      expect(comment.author.username, 'john_doe');
      expect(comment.author.avatarUrl, 'https://example.com/avatar.jpg');
      expect(comment.text, 'Incredible pilot episode!');
      expect(comment.rating, 5.0);
      expect(comment.likeCount, 42);
      expect(comment.replyCount, 3);
      expect(comment.isSpoiler, true);
      expect(comment.source, CommentSource.serializd);
    });

    test('fetchComments with MediaReviewsRequest (Movie) fetches Letterboxd reviews', () async {
      final letterboxdComment = Comment(
        id: 'lb_1',
        author: const CommentAuthor(id: 'lb_u', username: 'LetterboxdFan'),
        text: 'Loved this movie!',
        rating: 4.5,
        likeCount: 100,
        source: CommentSource.letterboxd,
      );

      when(
        () => mockLetterboxd.fetchMovieReviews(
          tmdbId: 550,
          imdbId: 'tt0137523',
          title: 'Fight Club',
          year: 1999,
          page: any(named: 'page'),
        ),
      ).thenAnswer((_) async => [letterboxdComment]);

      final reviews = await repository.fetchComments(
        const MediaReviewsRequest(
          tmdbId: 550,
          mediaType: MediaKind.movie,
          imdbId: 'tt0137523',
          title: 'Fight Club',
          year: 1999,
        ),
      );

      expect(reviews.length, 1);
      expect(reviews.first.source, CommentSource.letterboxd);
    });

    test('fetchComments with MediaReviewsRequest (TV) fetches Serializd reviews', () async {
      when(
        () => mockSerializd.fetchShowReviews(
          showId: 1399,
          page: any(named: 'page'),
        ),
      ).thenAnswer(
        (_) async => {
          'reviews': [
            {
              'id': 2001,
              'author': 'serializd_fan',
              'reviewText': 'Best series ever made.',
              'rating': 5,
              'numLikes': 200,
            }
          ]
        },
      );

      final reviews = await repository.fetchComments(
        const MediaReviewsRequest(
          tmdbId: 1399,
          mediaType: MediaKind.tv,
          imdbId: 'tt0903747',
        ),
      );

      expect(reviews.length, 1);
      expect(reviews.first.source, CommentSource.serializd);
    });

    test('fetchReplies maps Serializd comments correctly', () async {
      when(
        () => mockSerializd.fetchReviewComments('1001'),
      ).thenAnswer(
        (_) async => [
          {
            'id': 2001,
            'author': 'reply_user',
            'authorImageUrl': 'https://example.com/user2.jpg',
            'commentText': 'Totally agree with you!',
            'numLikes': 5,
            'dateAdded': '2024-01-02T10:00:00Z',
          }
        ],
      );

      final replies = await repository.fetchReplies('1001');

      expect(replies.length, 1);
      final reply = replies.first;
      expect(reply.id, '2001');
      expect(reply.author.username, 'reply_user');
      expect(reply.text, 'Totally agree with you!');
      expect(reply.likeCount, 5);
      expect(reply.source, CommentSource.serializd);
    });
  });
}
