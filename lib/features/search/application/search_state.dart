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

  const SearchState({
    this.query = '',
    this.results = const [],
    this.status = SearchStatus.initial,
    this.page = 1,
    this.hasMore = true,
    this.errorMessage,
  });

  SearchState copyWith({
    String? query,
    List<Map<String, dynamic>>? results,
    SearchStatus? status,
    int? page,
    bool? hasMore,
    String? errorMessage,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      status: status ?? this.status,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage ?? this.errorMessage,
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
      other.errorMessage == errorMessage;
  }

  @override
  int get hashCode {
    return query.hashCode ^
      results.hashCode ^
      status.hashCode ^
      page.hashCode ^
      hasMore.hashCode ^
      errorMessage.hashCode;
  }
}
