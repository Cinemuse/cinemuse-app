import 'dart:async';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/core/error/error_service.dart';
import 'package:cinemuse_app/features/search/application/search_state.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((
  ref,
) {
  ref.watch(tmdbServiceProvider);
  // A new notifier per account, so each one sees only its own history.
  return SearchNotifier(ref, userId: ref.watch(userIdProvider));
});

class SearchNotifier extends StateNotifier<SearchState> {
  final Ref _ref;
  TmdbService get _tmdbService => _ref.read(tmdbServiceProvider);
  Timer? _debounce;
  bool _isLoadingMore = false;

  /// Bumped on every new search or clear; an answer that comes back with an
  /// older number belongs to an old query and is dropped (REV-53).
  int _requestId = 0;

  /// Saved-history key, one per account (REV-62). Null when logged out:
  /// the history then lives in memory only.
  final String? _historyKey;

  /// The old device-wide key: nobody knows whose searches it holds.
  static const String _legacyHistoryKey = 'global_search_history';

  SearchNotifier(this._ref, {String? userId})
    : _historyKey = userId == null ? null : 'search_history_$userId',
      super(const SearchState()) {
    _loadSearchHistory();
  }

  Future<void> _loadSearchHistory() async {
    final key = _historyKey;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_legacyHistoryKey);
      final history = prefs.getStringList(key) ?? [];
      if (!mounted) return;
      state = state.copyWith(searchHistory: history);
    } catch (e) {
      // Only the saved history is lost; search still works.
      AppLogger.warn('Search', 'Could not load the search history', error: e);
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
    await _saveHistory(currentHistory);
  }

  Future<void> removeFromHistory(String query) async {
    final currentHistory = List<String>.from(state.searchHistory);
    if (currentHistory.remove(query)) {
      state = state.copyWith(searchHistory: currentHistory);
      await _saveHistory(currentHistory);
    }
  }

  Future<void> clearHistory() async {
    state = state.copyWith(searchHistory: const []);
    await _saveHistory(const []);
  }

  Future<void> _saveHistory(List<String> history) async {
    final key = _historyKey;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (history.isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setStringList(key, history);
      }
    } catch (e) {
      // Only the saved history is lost; search still works.
      AppLogger.warn('Search', 'Could not save the search history', error: e);
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
    // Enter searches right away: the pending typing search would repeat it.
    _debounce?.cancel();
    final requestId = ++_requestId;

    if (query.trim().isEmpty) {
      state = SearchState(searchHistory: state.searchHistory);
      return;
    }

    // A fresh state, so an old error message can't stay behind.
    state = SearchState(
      query: query,
      status: SearchStatus.loading,
      searchHistory: state.searchHistory,
    );

    try {
      final page = await _tmdbService.searchMulti(query, page: 1);
      if (!mounted || requestId != _requestId) return;

      state = state.copyWith(
        results: page.results,
        status: page.results.isEmpty
            ? SearchStatus.noResults
            : SearchStatus.loaded,
        page: 1,
        hasMore: page.totalPages > 1,
      );
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      final mapped = _ref.read(errorMapperProvider).map(e);
      state = state.copyWith(
        status: SearchStatus.error,
        errorMessage: mapped.message,
      );
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore ||
        !state.hasMore ||
        state.status != SearchStatus.loaded) {
      return;
    }

    _isLoadingMore = true;
    final nextPage = state.page + 1;
    final requestId = _requestId;

    try {
      final page = await _tmdbService.searchMulti(state.query, page: nextPage);
      if (!mounted || requestId != _requestId) return;

      // TMDB pages can overlap while results move; ids are per media type.
      final existingKeys = state.results.map(_resultKey).toSet();
      final uniqueNew = page.results
          .where((r) => !existingKeys.contains(_resultKey(r)))
          .toList();

      state = state.copyWith(
        results: [...state.results, ...uniqueNew],
        page: nextPage,
        hasMore: page.results.isNotEmpty && nextPage < page.totalPages,
      );
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      // Report load more errors globally via toast
      _ref.read(errorServiceProvider.notifier).handle(e);
      state = state.copyWith(hasMore: false);
    } finally {
      _isLoadingMore = false;
    }
  }

  static String _resultKey(Map<String, dynamic> r) =>
      '${r['media_type']}:${r['id']}';

  void clear() {
    _debounce?.cancel();
    _requestId++;
    state = SearchState(searchHistory: state.searchHistory);
  }
}
