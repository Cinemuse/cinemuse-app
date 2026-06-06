import 'package:flutter/foundation.dart';

enum SearchStatus { initial, loading, loaded, error, noResults }

@immutable
class SearchState {
  final String query;
  final List<Map<String, dynamic>> results;
  final SearchStatus status;
  final int page;
  final bool hasMore;
  final String? errorMessage;
  final List<String> searchHistory;

  const SearchState({
    this.query = '',
    this.results = const [],
    this.status = SearchStatus.initial,
    this.page = 1,
    this.hasMore = true,
    this.errorMessage,
    this.searchHistory = const [],
  });

  SearchState copyWith({
    String? query,
    List<Map<String, dynamic>>? results,
    SearchStatus? status,
    int? page,
    bool? hasMore,
    String? errorMessage,
    List<String>? searchHistory,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      status: status ?? this.status,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage ?? this.errorMessage,
      searchHistory: searchHistory ?? this.searchHistory,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SearchState &&
        other.query == query &&
        listEquals(other.results, results) &&
        other.status == status &&
        other.page == page &&
        other.hasMore == hasMore &&
        other.errorMessage == errorMessage &&
        listEquals(other.searchHistory, searchHistory);
  }

  @override
  int get hashCode {
    return query.hashCode ^
        results.hashCode ^
        status.hashCode ^
        page.hashCode ^
        hasMore.hashCode ^
        errorMessage.hashCode ^
        searchHistory.hashCode;
  }
}
