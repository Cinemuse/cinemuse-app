import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/error/error_service.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import '../presentation/widgets/explore_filters.dart';
import '../presentation/widgets/media_type_selector.dart';

// Not autoDispose: Explore keeps its tab and filters while the user is on
// other screens.
final exploreMediaTypeProvider =
    NotifierProvider<ExploreMediaTypeNotifier, MediaType>(
      ExploreMediaTypeNotifier.new,
    );

class ExploreMediaTypeNotifier extends Notifier<MediaType> {
  @override
  MediaType build() => MediaType.movie;

  /// Switches the tab and fits the filters to it (series use other genres
  /// and another date field).
  void select(MediaType type) {
    state = type;
    final filters = ref.read(exploreFiltersProvider);
    ref.read(exploreFiltersProvider.notifier).state = filters.forType(type);
  }
}

final exploreFiltersProvider = StateProvider<ExploreFilters>(
  (ref) => ExploreFilters(),
);

final exploreResultsProvider =
    AsyncNotifierProvider<ExploreResultsNotifier, List<Map<String, dynamic>>>(
      () {
        return ExploreResultsNotifier();
      },
    );

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
    final tmdbService = ref.watch(tmdbServiceProvider);

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
        watchProviders: filters.watchProviders,
        watchRegion: filters.watchRegion,
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
      state = AsyncValue.data([...state.value ?? [], ...nextResults]);
    } catch (e, st) {
      // Keep the results shown and step back, so the next scroll retries
      // this page; the toast tells the user it failed.
      _currentPage--;
      ref.read(errorServiceProvider.notifier).handle(e, stackTrace: st);
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

final watchProvidersListProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final tmdbService = ref.watch(tmdbServiceProvider);
  final mediaType = ref.watch(exploreMediaTypeProvider);
  final watchRegion = ref.watch(
    exploreFiltersProvider.select((f) => f.watchRegion),
  );

  return tmdbService.getWatchProviders(
    mediaType == MediaType.movie ? 'movie' : 'tv',
    watchRegion,
  );
});
