import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cinemuse_app/features/media/application/comments_provider.dart';
import 'package:cinemuse_app/features/media/data/comments_repository_provider.dart';
import 'package:cinemuse_app/features/media/domain/comment.dart';
import 'package:cinemuse_app/features/media/domain/comments_repository.dart';

class MockCommentsRepository extends Mock implements CommentsRepository {}

void main() {
  late MockCommentsRepository mockRepo;
  late ProviderContainer container;

  final sampleComment1 = Comment(
    id: '1',
    author: const CommentAuthor(id: 'u1', username: 'alice'),
    text: 'Old but liked',
    likeCount: 50,
    rating: 3.0,
    createdAt: DateTime.parse('2023-01-01T00:00:00Z'),
    source: CommentSource.serializd,
  );

  final sampleComment2 = Comment(
    id: '2',
    author: const CommentAuthor(id: 'u2', username: 'bob'),
    text: 'New and highly rated',
    likeCount: 10,
    rating: 5.0,
    createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
    source: CommentSource.serializd,
  );

  const testRequest = EpisodeCommentsRequest(
    tmdbShowId: 100,
    seasonNumber: 1,
    episodeNumber: 1,
  );

  setUp(() {
    mockRepo = MockCommentsRepository();
    container = ProviderContainer(
      overrides: [
        commentsRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('CommentsNotifier', () {
    test('fetches comments and sorts by most liked by default', () async {
      when(() => mockRepo.fetchComments(testRequest))
          .thenAnswer((_) async => [sampleComment2, sampleComment1]);

      final sub = container.listen(commentsProvider(testRequest), (_, __) {});

      while (container.read(commentsProvider(testRequest)).isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final state = container.read(commentsProvider(testRequest));
      expect(state.isLoading, false);
      expect(state.hasAnyComments, true);
      expect(state.comments.length, 2);
      expect(state.comments.first.id, '1'); // 50 likes > 10 likes
      expect(state.comments.last.id, '2');
      sub.close();
    });

    test('re-sorts comments when highestRating is selected', () async {
      when(() => mockRepo.fetchComments(testRequest))
          .thenAnswer((_) async => [sampleComment1, sampleComment2]);

      final sub = container.listen(commentsProvider(testRequest), (_, __) {});

      while (container.read(commentsProvider(testRequest)).isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final notifier = container.read(commentsProvider(testRequest).notifier);
      notifier.setSortType(CommentSortType.highestRating);

      final state = container.read(commentsProvider(testRequest));
      expect(state.sortType, CommentSortType.highestRating);
      expect(state.comments.first.id, '2'); // rating 5.0 > 3.0
      expect(state.comments.last.id, '1');
      sub.close();
    });

    test('re-sorts comments when recent is selected', () async {
      when(() => mockRepo.fetchComments(testRequest))
          .thenAnswer((_) async => [sampleComment1, sampleComment2]);

      final sub = container.listen(commentsProvider(testRequest), (_, __) {});

      while (container.read(commentsProvider(testRequest)).isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final notifier = container.read(commentsProvider(testRequest).notifier);
      notifier.setSortType(CommentSortType.recent);

      final state = container.read(commentsProvider(testRequest));
      expect(state.sortType, CommentSortType.recent);
      expect(state.comments.first.id, '2'); // 2024 > 2023
      expect(state.comments.last.id, '1');
      sub.close();
    });

    test('filters comments by source correctly', () async {
      final letterboxdComment = Comment(
        id: 'lb_1',
        author: const CommentAuthor(id: 'u3', username: 'carol'),
        text: 'Letterboxd review',
        likeCount: 5,
        source: CommentSource.letterboxd,
      );

      when(() => mockRepo.fetchComments(testRequest))
          .thenAnswer((_) async => [sampleComment1, letterboxdComment]);

      final sub = container.listen(commentsProvider(testRequest), (_, __) {});

      while (container.read(commentsProvider(testRequest)).isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final notifier = container.read(commentsProvider(testRequest).notifier);
      expect(container.read(commentsProvider(testRequest)).comments.length, 2);

      // Filter for Letterboxd only
      notifier.setSourceFilter(CommentSourceFilter.letterboxd);
      var state = container.read(commentsProvider(testRequest));
      expect(state.comments.length, 1);
      expect(state.comments.first.id, 'lb_1');

      // Filter for Serializd only
      notifier.setSourceFilter(CommentSourceFilter.serializd);
      state = container.read(commentsProvider(testRequest));
      expect(state.comments.length, 1);
      expect(state.comments.first.id, '1');

      // Reset to all
      notifier.setSourceFilter(CommentSourceFilter.all);
      state = container.read(commentsProvider(testRequest));
      expect(state.comments.length, 2);
      sub.close();
    });
  });
}
