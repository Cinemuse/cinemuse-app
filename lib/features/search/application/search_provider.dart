import 'dart:async';
import 'package:cinemuse_app/core/services/media/tmdb_service.dart';
import 'package:cinemuse_app/features/search/application/search_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref.read(tmdbServiceProvider));
});

class SearchNotifier extends StateNotifier<SearchState> {
  final TmdbService _tmdbService;
  Timer? _debounce;
  bool _isLoadingMore = false;

  SearchNotifier(this._tmdbService) : super(const SearchState());

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
      state = const SearchState();
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
      state = state.copyWith(
        status: SearchStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !state.hasMore || state.status != SearchStatus.loaded) return;

    _isLoadingMore = true;
    final nextPage = state.page + 1;

    try {
      final newResults = await _tmdbService.searchMulti(state.query, page: nextPage);
      
      if (newResults.isEmpty) {
        state = state.copyWith(hasMore: false);
      } else {
        // Dedup against existing
        final existingIds = state.results.map((r) => '${r['id']}').toSet();
        final uniqueNew = newResults.where((r) => !existingIds.contains('${r['id']}')).toList();

        state = state.copyWith(
          results: [...state.results, ...uniqueNew],
          page: nextPage,
          hasMore: newResults.length >= 20,
        );
      }
    } catch (e) {
      // Silent error on load more? Or show snackbar? For now just stop loading.
      state = state.copyWith(hasMore: false);
    } finally {
      _isLoadingMore = false;
    }
  }
  
  void clear() {
      state = const SearchState();
  }
}
