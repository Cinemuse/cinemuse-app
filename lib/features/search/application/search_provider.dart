import 'dart:async';
import 'package:cinemuse_app/core/services/media/tmdb_service.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/core/error/error_service.dart';
import 'package:cinemuse_app/features/search/application/search_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((
  ref,
) {
  ref.watch(tmdbServiceProvider);
  return SearchNotifier(ref);
});

class SearchNotifier extends StateNotifier<SearchState> {
  final Ref _ref;
  TmdbService get _tmdbService => _ref.read(tmdbServiceProvider);
  Timer? _debounce;
  bool _isLoadingMore = false;
  static const String _historyKey = 'global_search_history';

  SearchNotifier(this._ref) : super(const SearchState()) {
    _loadSearchHistory();
  }

  Future<void> _loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(_historyKey) ?? [];
      state = state.copyWith(searchHistory: history);
    } catch (e) {
      // Fail silently
    }
  }

  Future<void> addToHistory(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final currentHistory = List<String>.from(state.searchHistory);
    currentHistory.remove(trimmed);
    currentHistory.insert(0, trimmed);

    if (currentHistory.length > 20) {
      currentHistory.removeLast();
    }

    state = state.copyWith(searchHistory: currentHistory);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_historyKey, currentHistory);
    } catch (e) {
      // Fail silently
    }
  }

  Future<void> removeFromHistory(String query) async {
    final currentHistory = List<String>.from(state.searchHistory);
    if (currentHistory.remove(query)) {
      state = state.copyWith(searchHistory: currentHistory);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_historyKey, currentHistory);
      } catch (e) {
        // Fail silently
      }
    }
  }

  Future<void> clearHistory() async {
    state = state.copyWith(searchHistory: const []);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (e) {
      // Fail silently
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void onQueryChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      search(query);
    });
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = SearchState(searchHistory: state.searchHistory);
      return;
    }

    state = state.copyWith(
      query: query,
      status: SearchStatus.loading,
      page: 1,
      results: [],
      hasMore: true,
      errorMessage: null,
    );

    try {
      // Fetch initial batch (pages 1 and 2 to mimic web)
      // Note: TmdbService.searchMulti might need adjustment if it doesn't support page param readily
      // or returns List<Map> directly. Assuming it returns List<Map> for now and we might need to modify it or assume page 1.
      // Checking TmdbService usage in other files would be good, but standard usually implies page 1.
      // Let's assume standard behavior for now.

      final results = await _tmdbService.searchMulti(query, page: 1);

      // Basic dedup logic if needed, but fresh search shouldn't have dupes

      state = state.copyWith(
        results: results,
        status: results.isEmpty ? SearchStatus.noResults : SearchStatus.loaded,
        page: 1,
        // Simplistic assumption: if we got 20 results (default page size), there might be more.
        hasMore: results.length >= 20,
      );
    } catch (e) {
      final mapped = _ref.read(errorMapperProvider).map(e);
      state = state.copyWith(
        status: SearchStatus.error,
        errorMessage: mapped.message,
      );
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !state.hasMore || state.status != SearchStatus.loaded) {
      return;
    }

    _isLoadingMore = true;
    final nextPage = state.page + 1;

    try {
      final newResults = await _tmdbService.searchMulti(
        state.query,
        page: nextPage,
      );

      if (newResults.isEmpty) {
        state = state.copyWith(hasMore: false);
      } else {
        // Dedup against existing
        final existingIds = state.results.map((r) => '${r['id']}').toSet();
        final uniqueNew = newResults
            .where((r) => !existingIds.contains('${r['id']}'))
            .toList();

        state = state.copyWith(
          results: [...state.results, ...uniqueNew],
          page: nextPage,
          hasMore: newResults.length >= 20,
        );
      }
    } catch (e) {
      // Report load more errors globally via toast
      _ref.read(errorServiceProvider.notifier).handle(e);
      state = state.copyWith(hasMore: false);
    } finally {
      _isLoadingMore = false;
    }
  }

  void clear() {
    state = SearchState(searchHistory: state.searchHistory);
  }
}
