import 'package:cinemuse_app/core/services/media/tmdb_service.dart';
import 'package:cinemuse_app/features/media/application/watch_history_store.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final trendingProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final tmdbService = ref.read(tmdbServiceProvider);
  return tmdbService.getTrending();
});

final popularMoviesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final tmdbService = ref.read(tmdbServiceProvider);
  return tmdbService.getPopularMovies();
});

final popularSeriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final tmdbService = ref.read(tmdbServiceProvider);
  return tmdbService.getPopularSeries();
});

final continueWatchingProvider = StreamProvider<List<WatchHistory>>((ref) {
  final historyMapAsync = ref.watch(watchHistoryStoreProvider);
  
  return historyMapAsync.when(
    data: (historyMap) {
      // 1. Group by tmdbId and find the latest entry for each
      final latestByTmdbId = <int, WatchHistory>{};
      
      for (final item in historyMap.values) {
        final existing = latestByTmdbId[item.tmdbId];
        if (existing == null || item.lastWatchedAt.isAfter(existing.lastWatchedAt)) {
          latestByTmdbId[item.tmdbId] = item;
        }
      }

      // 2. Filter these LATEST entries to only keep those currently being watched
      final list = latestByTmdbId.values
          .where((item) => item.status == WatchStatus.watching)
          .toList();
      
      // 3. Sort by last watched (descending)
      list.sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));
      return Stream.value(list);
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});
