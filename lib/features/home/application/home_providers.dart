import 'package:cinemuse_app/core/services/stream_resolver.dart';
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

final continueWatchingProvider = FutureProvider<List<WatchHistory>>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];
  
  final repo = ref.read(watchHistoryRepositoryProvider);
  return repo.getContinueWatching(userId);
});
