import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/media/data/comments_repository_provider.dart';
import 'package:cinemuse_app/features/media/domain/comment.dart';
import 'package:cinemuse_app/features/media/domain/comments_repository.dart';

enum CommentSortType {
  mostLiked,
  recent,
  highestRating,
}

enum CommentSourceFilter {
  all,
  serializd,
  letterboxd,
  imdb,
}

class CommentsState {
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;
  final bool hasAnyComments;
  final List<Comment> comments;
  final String? error;
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
    String? error,
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
      final p1 = await repository.fetchComments(arg, page: 1);
      final p2 = await repository.fetchComments(arg, page: 2);

      final combined = <Comment>[];
      final seenIds = <String>{};
      for (final c in [...p1, ...p2]) {
        if (seenIds.add(c.id)) {
          combined.add(c);
        }
      }

      _allComments = combined;
      _currentPage = p2.isNotEmpty ? 2 : 1;
      _applySortAndFilter();
      state = state.copyWith(
        hasMore: p2.isNotEmpty,
        currentPage: _currentPage,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
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
      final updatedComments = List<Comment>.from(state.comments)..addAll(filteredFresh);

      state = state.copyWith(
        isLoadingMore: false,
        currentPage: _currentPage,
        hasMore: true,
        comments: updatedComments,
        availableSources: _allComments.map((c) => c.source).toSet(),
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void setSortType(CommentSortType sortType) {
    if (state.sortType == sortType) return;
    state = state.copyWith(sortType: sortType);
    _applySortAndFilter();
  }

  void setSourceFilter(CommentSourceFilter filter) {
    if (state.sourceFilter == filter) return;
    state = state.copyWith(sourceFilter: filter);
    _applySortAndFilter();
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
