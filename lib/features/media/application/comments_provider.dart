import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/media/data/comments_repository_provider.dart';
import 'package:cinemuse_app/features/media/domain/comment.dart';
import 'package:cinemuse_app/features/media/domain/comments_repository.dart';

enum CommentSortType { mostLiked, recent, highestRating }

enum CommentSourceFilter { all, serializd, letterboxd, imdb }

class CommentsState {
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;
  final bool hasAnyComments;
  final List<Comment> comments;

  /// Shown through the error mapper, never as raw text (REV-201).
  final Object? error;
  final CommentSortType sortType;
  final CommentSourceFilter sourceFilter;
  final Set<CommentSource> availableSources;

  const CommentsState({
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.currentPage = 1,
    this.hasAnyComments = false,
    this.comments = const [],
    this.error,
    this.sortType = CommentSortType.mostLiked,
    this.sourceFilter = CommentSourceFilter.all,
    this.availableSources = const {},
  });

  CommentsState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
    bool? hasAnyComments,
    List<Comment>? comments,
    Object? error,
    CommentSortType? sortType,
    CommentSourceFilter? sourceFilter,
    Set<CommentSource>? availableSources,
  }) {
    return CommentsState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      hasAnyComments: hasAnyComments ?? this.hasAnyComments,
      comments: comments ?? this.comments,
      error: error,
      sortType: sortType ?? this.sortType,
      sourceFilter: sourceFilter ?? this.sourceFilter,
      availableSources: availableSources ?? this.availableSources,
    );
  }
}

class CommentsNotifier
    extends AutoDisposeFamilyNotifier<CommentsState, CommentsRequest> {
  List<Comment> _allComments = [];
  int _currentPage = 1;

  // A filter only hides loaded comments, and the sheet loads more only on
  // scroll: with fewer than this left, load a few pages by itself (REV-209).
  // After that the sheet offers "Load more" while [CommentsState.hasMore].
  static const _minFilteredComments = 10;
  static const _maxAutoPages = 3;

  @override
  CommentsState build(CommentsRequest arg) {
    Future.microtask(_fetchComments);
    return const CommentsState();
  }

  Future<void> _fetchComments() async {
    state = state.copyWith(isLoading: true, error: null, hasMore: true);
    _currentPage = 1;

    try {
      final repository = ref.read(commentsRepositoryProvider);
      final firstPage = await repository.fetchComments(arg, page: 1);
      _allComments = {for (final c in firstPage) c.id: c}.values.toList();
      _applySortAndFilter();
      state = state.copyWith(hasMore: firstPage.isNotEmpty, currentPage: 1);
    } catch (e, stack) {
      AppLogger.error(
        'CommentsNotifier',
        'Failed to load initial comments for $arg',
        error: e,
        stackTrace: stack,
      );
      state = state.copyWith(isLoading: false, error: e);
      return;
    }
    // Page 1 shows at once; page 2 is added below it (user, REV-201). Not
    // both at once: IMDb's page 2 needs the cursor page 1 returns.
    await loadNextPage();
  }

  Future<void> loadNextPage() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final repository = ref.read(commentsRepositoryProvider);
      final nextPage = _currentPage + 1;
      final newComments = await repository.fetchComments(arg, page: nextPage);

      if (newComments.isEmpty) {
        state = state.copyWith(isLoadingMore: false, hasMore: false);
        return;
      }

      final seenIds = _allComments.map((c) => c.id).toSet();
      final freshBatch = <Comment>[];
      for (final c in newComments) {
        if (seenIds.add(c.id)) {
          _allComments.add(c);
          freshBatch.add(c);
        }
      }

      _currentPage = nextPage;

      if (freshBatch.isEmpty) {
        state = state.copyWith(isLoadingMore: false, hasMore: false);
        return;
      }

      // Filter and sort ONLY the newly fetched batch so existing items above the viewport are undisturbed
      final filteredFresh = _filterAndSortBatch(freshBatch);
      final updatedComments = List<Comment>.from(state.comments)
        ..addAll(filteredFresh);

      state = state.copyWith(
        isLoadingMore: false,
        currentPage: _currentPage,
        hasMore: true,
        comments: updatedComments,
        availableSources: _allComments.map((c) => c.source).toSet(),
      );
    } catch (e, stack) {
      // Safe to go on: the comments already shown stay.
      AppLogger.warn(
        'CommentsNotifier',
        'Failed to load next comments page for $arg',
        error: e,
        stackTrace: stack,
      );
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void setSortType(CommentSortType sortType) {
    if (state.sortType == sortType) return;
    state = state.copyWith(sortType: sortType);
    _applySortAndFilter();
  }

  Future<void> setSourceFilter(CommentSourceFilter filter) async {
    if (state.sourceFilter == filter) return;
    state = state.copyWith(sourceFilter: filter);
    _applySortAndFilter();
    for (var i = 0; i < _maxAutoPages; i++) {
      if (state.comments.length >= _minFilteredComments ||
          !state.hasMore ||
          state.isLoading ||
          state.isLoadingMore) {
        return;
      }
      await loadNextPage();
    }
  }

  List<Comment> _filterAndSortBatch(List<Comment> batch) {
    var filtered = List<Comment>.from(batch);

    if (state.sourceFilter != CommentSourceFilter.all) {
      filtered = filtered.where((c) {
        switch (state.sourceFilter) {
          case CommentSourceFilter.serializd:
            return c.source == CommentSource.serializd;
          case CommentSourceFilter.letterboxd:
            return c.source == CommentSource.letterboxd;
          case CommentSourceFilter.imdb:
            return c.source == CommentSource.imdb;
          case CommentSourceFilter.all:
            return true;
        }
      }).toList();
    }

    switch (state.sortType) {
      case CommentSortType.mostLiked:
        filtered.sort((a, b) => b.likeCount.compareTo(a.likeCount));
        break;
      case CommentSortType.highestRating:
        filtered.sort((a, b) {
          final rA = a.rating ?? 0.0;
          final rB = b.rating ?? 0.0;
          return rB.compareTo(rA);
        });
        break;
      case CommentSortType.recent:
        filtered.sort((a, b) {
          final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
        break;
    }

    return filtered;
  }

  void _applySortAndFilter() {
    final filtered = _filterAndSortBatch(_allComments);

    state = state.copyWith(
      isLoading: false,
      hasAnyComments: _allComments.isNotEmpty,
      comments: filtered,
      availableSources: _allComments.map((c) => c.source).toSet(),
    );
  }
}

/// Active Riverpod provider for comments and reviews state.
final commentsProvider = NotifierProvider.autoDispose
    .family<CommentsNotifier, CommentsState, CommentsRequest>(
      CommentsNotifier.new,
    );
