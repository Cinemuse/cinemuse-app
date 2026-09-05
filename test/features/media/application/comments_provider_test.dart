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
      when(() => mockRepo.fetchComments(testRequest, page: any(named: 'page')))
          .thenAnswer((invocation) async {
        final page = invocation.namedArguments[#page] as int? ?? 1;
        return page == 1 ? [sampleComment2, sampleComment1] : [];
      });

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
      when(() => mockRepo.fetchComments(testRequest, page: any(named: 'page')))
          .thenAnswer((invocation) async {
        final page = invocation.namedArguments[#page] as int? ?? 1;
        return page == 1 ? [sampleComment1, sampleComment2] : [];
      });

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
      when(() => mockRepo.fetchComments(testRequest, page: any(named: 'page')))
          .thenAnswer((invocation) async {
        final page = invocation.namedArguments[#page] as int? ?? 1;
        return page == 1 ? [sampleComment1, sampleComment2] : [];
      });

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

    test('filters comments by source correctly including IMDb', () async {
      final letterboxdComment = Comment(
        id: 'lb_1',
        author: const CommentAuthor(id: 'u3', username: 'carol'),
        text: 'Letterboxd review',
        likeCount: 5,
        source: CommentSource.letterboxd,
      );

      final imdbComment = Comment(
        id: 'imdb_1',
        author: const CommentAuthor(id: 'u4', username: 'dave'),
        text: 'IMDb review',
        likeCount: 20,
        source: CommentSource.imdb,
      );

      when(() => mockRepo.fetchComments(testRequest, page: any(named: 'page')))
          .thenAnswer((invocation) async {
        final page = invocation.namedArguments[#page] as int? ?? 1;
        return page == 1 ? [sampleComment1, letterboxdComment, imdbComment] : [];
      });

      final sub = container.listen(commentsProvider(testRequest), (_, __) {});

      while (container.read(commentsProvider(testRequest)).isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final notifier = container.read(commentsProvider(testRequest).notifier);
      expect(container.read(commentsProvider(testRequest)).comments.length, 3);
      expect(
        container.read(commentsProvider(testRequest)).availableSources,
        {CommentSource.serializd, CommentSource.letterboxd, CommentSource.imdb},
      );

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

      // Filter for IMDb only
      notifier.setSourceFilter(CommentSourceFilter.imdb);
      state = container.read(commentsProvider(testRequest));
      expect(state.comments.length, 1);
      expect(state.comments.first.id, 'imdb_1');

      // Reset to all
      notifier.setSourceFilter(CommentSourceFilter.all);
      state = container.read(commentsProvider(testRequest));
      expect(state.comments.length, 3);
      sub.close();
    });

    test('loadNextPage strictly appends new batch without disturbing order of existing items', () async {
      final page1CommentA = Comment(
        id: 'p1_a',
        author: const CommentAuthor(id: 'u1', username: 'alice'),
        text: 'Page 1 item A',
        likeCount: 50,
        source: CommentSource.letterboxd,
      );

      final page1CommentB = Comment(
        id: 'p1_b',
        author: const CommentAuthor(id: 'u2', username: 'bob'),
        text: 'Page 1 item B',
        likeCount: 20,
        source: CommentSource.letterboxd,
      );

      final page2CommentHighLikes = Comment(
        id: 'p2_high',
        author: const CommentAuthor(id: 'u3', username: 'carol'),
        text: 'Page 2 item with 100 likes',
        likeCount: 100, // higher than page 1 items!
        source: CommentSource.imdb,
      );

      when(() => mockRepo.fetchComments(testRequest, page: 1))
          .thenAnswer((_) async => [page1CommentA]);
      when(() => mockRepo.fetchComments(testRequest, page: 2))
          .thenAnswer((_) async => [page1CommentB]);
      when(() => mockRepo.fetchComments(testRequest, page: 3))
          .thenAnswer((_) async => [page2CommentHighLikes]);

      final sub = container.listen(commentsProvider(testRequest), (_, __) {});

      while (container.read(commentsProvider(testRequest)).isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final notifier = container.read(commentsProvider(testRequest).notifier);
      final initialState = container.read(commentsProvider(testRequest));
      expect(initialState.comments.length, 2);
      expect(initialState.comments[0].id, 'p1_a');
      expect(initialState.comments[1].id, 'p1_b');

      // Load next page
      await notifier.loadNextPage();

      final paginatedState = container.read(commentsProvider(testRequest));
      expect(paginatedState.comments.length, 3);
      // Items 0 and 1 MUST remain unchanged so the viewport does not jump
      expect(paginatedState.comments[0].id, 'p1_a');
      expect(paginatedState.comments[1].id, 'p1_b');
      // The new item must be appended at index 2
      expect(paginatedState.comments[2].id, 'p2_high');

      sub.close();
    });
  });
}
