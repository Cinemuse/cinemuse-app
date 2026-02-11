import 'package:cinemuse_app/core/services/stream_resolver.dart';
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
