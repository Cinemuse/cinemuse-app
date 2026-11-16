import 'dart:async';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/core/error/error_service.dart';
import 'package:cinemuse_app/features/search/application/search_state.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Kept alive: the last search stays when the overlay is opened again.
final searchProvider = NotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);

class SearchNotifier extends Notifier<SearchState> {
  TmdbService get _tmdbService => ref.read(tmdbServiceProvider);
  Timer? _debounce;
  bool _isLoadingMore = false;

  /// Bumped on every new search or clear; an answer that comes back with an
  /// older number belongs to an old query and is dropped (REV-53).
  int _requestId = 0;

  /// Saved-history key, one per account (REV-62). Null when logged out:
  /// the history then lives in memory only.
  String? _historyKey;

  /// The old device-wide key: nobody knows whose searches it holds.
  static const String _legacyHistoryKey = 'global_search_history';

  @override
  SearchState build() {
    ref.watch(tmdbServiceProvider);
    // Starts over on an account switch, so each account sees only its own
    // history.
    final userId = ref.watch(userIdProvider);
    _historyKey = userId == null ? null : 'search_history_$userId';
    _requestId++;
    _isLoadingMore = false;
    ref.onDispose(() => _debounce?.cancel());
    unawaited(_loadSearchHistory()); // logs its own failure
    return const SearchState();
  }

  Future<void> _loadSearchHistory() async {
    final key = _historyKey;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_legacyHistoryKey);
      final history = prefs.getStringList(key) ?? [];
      // Dropped if the account changed meanwhile.
      if (!ref.mounted || key != _historyKey) return;
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
      if (!ref.mounted || requestId != _requestId) return;

      state = state.copyWith(
        results: page.results,
        status: page.results.isEmpty
            ? SearchStatus.noResults
            : SearchStatus.loaded,
        page: 1,
        hasMore: page.totalPages > 1,
      );
    } catch (e) {
      if (!ref.mounted || requestId != _requestId) return;
      final mapped = ref.read(errorMapperProvider).map(e);
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
      if (!ref.mounted || requestId != _requestId) return;

      // TMDB pages can overlap while results move; ids are per media type.
      final existingKeys = state.results.map((r) => r.key).toSet();
      final uniqueNew = page.results
          .where((r) => !existingKeys.contains(r.key))
          .toList();

      state = state.copyWith(
        results: [...state.results, ...uniqueNew],
        page: nextPage,
        hasMore: page.results.isNotEmpty && nextPage < page.totalPages,
      );
    } catch (e) {
      if (!ref.mounted || requestId != _requestId) return;
      // Report load more errors globally via toast
      ref.read(errorServiceProvider.notifier).handle(e);
      state = state.copyWith(hasMore: false);
    } finally {
      _isLoadingMore = false;
    }
  }

  void clear() {
    _debounce?.cancel();
    _requestId++;
    state = SearchState(searchHistory: state.searchHistory);
  }
}
