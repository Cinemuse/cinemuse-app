import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import 'package:cinemuse_app/features/media/domain/tvtime_comment.dart';
import 'package:cinemuse_app/features/media/data/tvtime_service.dart';

enum CommentSortType { mostLiked, recent }

enum CommentLanguageFilter { unfiltered, english, italian, englishAndItalian }

abstract class CommentsRequest extends Equatable {
  const CommentsRequest();
}

class SeriesCommentsRequest extends CommentsRequest {
  final int tvdbId;
  const SeriesCommentsRequest(this.tvdbId);
  @override List<Object?> get props => [tvdbId];
}

class MovieCommentsRequest extends CommentsRequest {
  final String imdbId;
  const MovieCommentsRequest(this.imdbId);
  @override List<Object?> get props => [imdbId];
}

class EpisodeCommentsRequest extends CommentsRequest {
  final int tvdbShowId;
  final int season;
  final int episode;
  const EpisodeCommentsRequest(this.tvdbShowId, this.season, this.episode);
  @override List<Object?> get props => [tvdbShowId, season, episode];
}

class TvTimeCommentsState {
  final bool isLoading;
  final bool hasAnyComments;
  final List<TvTimeComment> comments;
  final String? error;
  final CommentSortType sortType;
  final CommentLanguageFilter languageFilter;

  const TvTimeCommentsState({
    this.isLoading = true,
    this.hasAnyComments = false,
    this.comments = const [],
    this.error,
    this.sortType = CommentSortType.mostLiked,
    this.languageFilter = CommentLanguageFilter.unfiltered,
  });

  TvTimeCommentsState copyWith({
    bool? isLoading,
    bool? hasAnyComments,
    List<TvTimeComment>? comments,
    String? error,
    CommentSortType? sortType,
    CommentLanguageFilter? languageFilter,
  }) {
    return TvTimeCommentsState(
      isLoading: isLoading ?? this.isLoading,
      hasAnyComments: hasAnyComments ?? this.hasAnyComments,
      comments: comments ?? this.comments,
      error: error,
      sortType: sortType ?? this.sortType,
      languageFilter: languageFilter ?? this.languageFilter,
    );
  }
}

class TvTimeCommentsNotifier
    extends AutoDisposeFamilyNotifier<TvTimeCommentsState, CommentsRequest> {
  List<TvTimeComment> _allComments = [];

  @override
  TvTimeCommentsState build(CommentsRequest arg) {
    Future.microtask(_fetchComments);
    return const TvTimeCommentsState();
  }

  Future<void> _fetchComments() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final service = ref.read(tvTimeServiceProvider);
      List<TvTimeComment> fetchedComments = [];

      final request = this.arg;

      // We pass limit=9999 just in case, though TVTime currently ignores it and returns all.
      // We also don't rely on their sort since we do it client-side.
      if (request is SeriesCommentsRequest) {
        fetchedComments = await service.fetchSeriesComments(request.tvdbId, limit: 9999);
      } else if (request is MovieCommentsRequest) {
        fetchedComments = await service.fetchMovieComments(request.imdbId, limit: 9999);
      } else if (request is EpisodeCommentsRequest) {
        fetchedComments = await service.fetchEpisodeComments(
          request.tvdbShowId,
          season: request.season,
          episode: request.episode,
          limit: 9999,
        );
      }

      _allComments = List.of(fetchedComments);
      _applySortAndFilter();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setSortType(CommentSortType sortType) {
    if (state.sortType == sortType) return;
    state = state.copyWith(sortType: sortType);
    _applySortAndFilter();
  }

  void setLanguageFilter(CommentLanguageFilter filter) {
    if (state.languageFilter == filter) return;
    state = state.copyWith(languageFilter: filter);
    _applySortAndFilter();
  }

  void _applySortAndFilter() {
    var filtered = List<TvTimeComment>.from(_allComments);

    switch (state.languageFilter) {
      case CommentLanguageFilter.english:
        filtered = filtered.where((c) => c.language == 'en').toList();
        break;
      case CommentLanguageFilter.italian:
        filtered = filtered.where((c) => c.language == 'it').toList();
        break;
      case CommentLanguageFilter.englishAndItalian:
        filtered = filtered.where((c) => c.language == 'en' || c.language == 'it').toList();
        break;
      case CommentLanguageFilter.unfiltered:
        break;
    }

    if (state.sortType == CommentSortType.mostLiked) {
      filtered.sort((a, b) => b.likeCount.compareTo(a.likeCount));
    } else {
      filtered.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    }

    state = state.copyWith(
      isLoading: false,
      hasAnyComments: _allComments.isNotEmpty,
      comments: filtered,
    );
  }
}

final tvTimeCommentsProvider = NotifierProvider.autoDispose.family<
    TvTimeCommentsNotifier, TvTimeCommentsState, CommentsRequest>(
  TvTimeCommentsNotifier.new,
);
