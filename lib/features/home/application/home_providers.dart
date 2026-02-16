import 'package:cinemuse_app/core/services/stream_resolver.dart';
import 'package:cinemuse_app/features/media/application/store/watch_history_store.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final trendingProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final resolver = ref.read(streamResolverProvider);
  return resolver.getTrending();
});

final popularMoviesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final resolver = ref.read(streamResolverProvider);
  return resolver.getPopularMovies();
});

final popularSeriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final resolver = ref.read(streamResolverProvider);
  return resolver.getPopularSeries();
});

final continueWatchingProvider = StreamProvider<List<WatchHistory>>((ref) {
  final historyMapAsync = ref.watch(watchHistoryStoreProvider);
  
  return historyMapAsync.when(
    data: (historyMap) {
      final list = historyMap.values
          .where((item) => item.status == WatchStatus.watching)
          .toList();
      
      // Sort by last watched (descending)
      list.sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));
      return Stream.value(list);
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});
