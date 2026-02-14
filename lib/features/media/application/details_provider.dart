import 'package:cinemuse_app/core/services/tmdb_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Family provider to fetch details for a specific media item
final mediaDetailsProvider = FutureProvider.family<Map<String, dynamic>?, ({String id, String type})>((ref, args) async {
  final tmdbService = ref.read(tmdbServiceProvider);
  return tmdbService.getMediaDetails(args.id, args.type);
});

// Family provider to fetch season details
final seasonDetailsProvider = FutureProvider.family<Map<String, dynamic>?, ({int tmdbId, int seasonNumber})>((ref, args) async {
  final tmdbService = ref.read(tmdbServiceProvider);
  return tmdbService.getSeasonDetails(args.tmdbId, args.seasonNumber);
});

// State provider for the currently selected season number
final selectedSeasonProvider = StateProvider.autoDispose<int>((ref) => 1);
