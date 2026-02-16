import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/tmdb_service.dart';
import '../presentation/widgets/explore_filters.dart';
import '../presentation/widgets/media_type_selector.dart';

final exploreMediaTypeProvider = StateProvider<MediaType>((ref) => MediaType.movie);

final exploreFiltersProvider = StateProvider<ExploreFilters>((ref) => const ExploreFilters());

final exploreResultsProvider = AsyncNotifierProvider<ExploreResultsNotifier, List<Map<String, dynamic>>>(() {
  return ExploreResultsNotifier();
});

class ExploreResultsNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isFetching = false;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    _currentPage = 1;
    _hasMore = true;
    _isFetching = false;
    return _fetch();
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    final mediaType = ref.watch(exploreMediaTypeProvider);
    final filters = ref.watch(exploreFiltersProvider);
    final tmdbService = ref.read(tmdbServiceProvider);

    if (mediaType == MediaType.person) {
      final res = await tmdbService.getPopularPersons(_currentPage);
      _hasMore = _currentPage < (res['total_pages'] ?? 0);
      return List<Map<String, dynamic>>.from(res['results'] ?? []);
    } else {
      final res = await tmdbService.discover(
        type: mediaType == MediaType.movie ? 'movie' : 'tv',
        page: _currentPage,
        sortBy: filters.sortBy,
        genres: filters.genres,
        languages: filters.languages,
        minRating: filters.rating.start,
        maxRating: filters.rating.end,
        minYear: filters.year.start.round(),
        maxYear: filters.year.end.round(),
        minVotes: filters.voteCount.start.round(),
        maxVotes: filters.voteCount.end.round(),
        minRuntime: filters.runtime.start.round(),
        maxRuntime: filters.runtime.end.round(),
      );
      _hasMore = _currentPage < (res['total_pages'] ?? 0);
      return List<Map<String, dynamic>>.from(res['results'] ?? []);
    }
  }

  Future<void> fetchNextPage() async {
    if (state.isLoading || !_hasMore || _isFetching) return;

    _isFetching = true;
    _currentPage++;
    
    try {
      final nextResults = await _fetch();
      state = AsyncValue.data([
        ...state.value ?? [],
        ...nextResults,
      ]);
    } finally {
      _isFetching = false;
    }
  }

  void reset() {
    _currentPage = 1;
    _hasMore = true;
    _isFetching = false;
    ref.invalidateSelf();
  }
}
