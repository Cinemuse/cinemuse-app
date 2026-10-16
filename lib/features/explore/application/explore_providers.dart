import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/error/error_service.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/settings/application/watch_region_providers.dart';
import '../domain/explore_filters.dart';
import '../domain/explore_type.dart';

// Not autoDispose: Explore keeps its tab and filters while the user is on
// other screens.
final exploreMediaTypeProvider =
    NotifierProvider<ExploreMediaTypeNotifier, ExploreType>(
      ExploreMediaTypeNotifier.new,
    );

class ExploreMediaTypeNotifier extends Notifier<ExploreType> {
  @override
  ExploreType build() => ExploreType.movie;

  /// Switches the tab and fits the filters to it (series use other genres
  /// and another date field).
  void select(ExploreType type) {
    state = type;
    final filters = ref.read(exploreFiltersProvider);
    ref.read(exploreFiltersProvider.notifier).set(filters.forType(type));
  }
}

// Not autoDispose: same as the tab above.
final exploreFiltersProvider =
    NotifierProvider<ExploreFiltersNotifier, ExploreFilters>(
      ExploreFiltersNotifier.new,
    );

/// The filter panel's choices; each method is one user action.
class ExploreFiltersNotifier extends Notifier<ExploreFilters> {
  @override
  ExploreFilters build() => ExploreFilters();

  void set(ExploreFilters filters) => state = filters;

  void clear() => state = ExploreFilters();

  void toggleGenre(int genreId) => state = state.toggleGenre(genreId);

  void toggleWatchProvider(int providerId) =>
      state = state.toggleWatchProvider(providerId);

  void addLanguage(String code) => state = state.addLanguage(code);

  void removeLanguage(String code) => state = state.removeLanguage(code);
}

final exploreResultsProvider =
    AsyncNotifierProvider<ExploreResultsNotifier, ExploreResults>(
      ExploreResultsNotifier.new,
    );

/// The Explore grid: the pages loaded so far.
class ExploreResults {
  final List<Map<String, dynamic>> items;
  final bool hasMore;

  /// A next page is loading (shows the spinner under the grid).
  final bool isLoadingMore;

  const ExploreResults({
    required this.items,
    required this.hasMore,
    this.isLoadingMore = false,
  });
}

class ExploreResultsNotifier extends AsyncNotifier<ExploreResults> {
  late TmdbService _tmdb;
  late ExploreType _type;
  late ExploreFilters _filters;
  late String _watchRegion;
  int _page = 1;
  // Bumped on every rebuild, so a next page still loading for the old
  // type/filters is dropped instead of appended to the new results.
  int _generation = 0;

  @override
  Future<ExploreResults> build() async {
    _tmdb = ref.watch(tmdbServiceProvider);
    _type = ref.watch(exploreMediaTypeProvider);
    _filters = ref.watch(exploreFiltersProvider);
    _watchRegion = ref.watch(watchRegionProvider);
    _generation++;
    _page = 1;
    return _fetchPage(1);
  }

  Future<ExploreResults> _fetchPage(int page) async {
    final res = _type == ExploreType.person
        ? await _tmdb.getPopularPersons(page)
        : await _tmdb.discover(
            type: _type == ExploreType.movie ? 'movie' : 'tv',
            page: page,
            sortBy: _filters.sortBy,
            genres: _filters.genres,
            languages: _filters.languages,
            minRating: _filters.rating.start,
            maxRating: _filters.rating.end,
            minYear: _filters.year.start.round(),
            maxYear: _filters.year.end.round(),
            minVotes: _filters.voteCount.start.round(),
            maxVotes: _filters.voteCount.end.round(),
            minRuntime: _filters.runtime.start.round(),
            maxRuntime: _filters.runtime.end.round(),
            watchProviders: _filters.watchProviders,
            watchRegion: _watchRegion,
          );
    return ExploreResults(
      items: List<Map<String, dynamic>>.from(res['results'] ?? []),
      hasMore: page < (res['total_pages'] ?? 0),
    );
  }

  Future<void> fetchNextPage() async {
    final current = state.valueOrNull;
    if (state.isLoading ||
        current == null ||
        !current.hasMore ||
        current.isLoadingMore) {
      return;
    }

    final generation = _generation;
    state = AsyncData(
      ExploreResults(items: current.items, hasMore: true, isLoadingMore: true),
    );

    try {
      final next = await _fetchPage(_page + 1);
      if (generation != _generation) return;
      _page++;
      state = AsyncData(
        ExploreResults(
          items: [...current.items, ...next.items],
          hasMore: next.hasMore,
        ),
      );
    } catch (e, st) {
      if (generation != _generation) return;
      // Keep the results shown, so the next scroll retries this page; the
      // toast tells the user it failed.
      state = AsyncData(current);
      ref.read(errorServiceProvider.notifier).handle(e, stackTrace: st);
    }
  }
}

/// How many streaming services the filter panel shows.
const _mainWatchProviderCount = 8;

/// The [count] services TMDB ranks first in [region] (its
/// `display_priorities`, falling back to the global `display_priority`).
List<Map<String, dynamic>> mainWatchProviders(
  List<Map<String, dynamic>> providers,
  String region, {
  int count = _mainWatchProviderCount,
}) {
  int priorityOf(Map<String, dynamic> p) {
    final byRegion = p['display_priorities'];
    final regional = byRegion is Map ? byRegion[region] : null;
    return ((regional ?? p['display_priority']) as num?)?.toInt() ?? 1 << 30;
  }

  final sorted = [...providers]
    ..sort((a, b) => priorityOf(a).compareTo(priorityOf(b)));
  return sorted.take(count).toList();
}

/// The main streaming services for the current media type and region.
final watchProvidersListProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final tmdbService = ref.watch(tmdbServiceProvider);
  final mediaType = ref.watch(exploreMediaTypeProvider);
  final watchRegion = ref.watch(watchRegionProvider);

  final providers = await tmdbService.getWatchProviders(
    mediaType == ExploreType.movie ? 'movie' : 'tv',
    watchRegion,
  );
  return mainWatchProviders(providers, watchRegion);
});
