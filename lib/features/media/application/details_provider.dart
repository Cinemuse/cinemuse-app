import 'package:cinemuse_app/core/services/tmdb_service.dart';
import 'package:cinemuse_app/features/media/application/store/watch_history_store.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Family provider to fetch details for a specific media item
final mediaDetailsProvider = FutureProvider.family<Map<String, dynamic>?, ({String id, String type})>((ref, args) async {
  final tmdbService = ref.read(tmdbServiceProvider);
  final details = await tmdbService.getMediaDetails(args.id, args.type);
  
  if (details != null) {
    // Naturally cache the item when we discover its details
    final repo = ref.read(watchHistoryRepositoryProvider);
    final mediaItem = MediaItem(
      tmdbId: int.parse(args.id),
      mediaType: MediaItem.fromString(args.type),
      title: details['title'] ?? details['name'] ?? 'Unknown',
      posterPath: details['poster_path'],
      backdropPath: details['backdrop_path'],
      releaseDate: DateTime.tryParse(details['release_date'] ?? details['first_air_date'] ?? ''),
      updatedAt: DateTime.now(),
    );
    // Use fire-and-forget for caching to not block UI
    repo.ensureMediaCached(mediaItem).catchError((e) => print('Background caching failed: $e'));
  }
  
  return details;
});

// Family provider to fetch season details
final seasonDetailsProvider = FutureProvider.family<Map<String, dynamic>?, ({int tmdbId, int seasonNumber})>((ref, args) async {
  final tmdbService = ref.read(tmdbServiceProvider);
  return tmdbService.getSeasonDetails(args.tmdbId, args.seasonNumber);
});

// State provider for the currently selected season number
final selectedSeasonProvider = StateProvider.autoDispose<int>((ref) => 1);

// Family provider to fetch watch history for a specific media item (Derived from Store)
final mediaWatchHistoryProvider = Provider.family<AsyncValue<WatchHistory?>, String>((ref, tmdbId) {
  final store = ref.watch(watchHistoryStoreProvider);
  return store.whenData((map) => map[tmdbId]);
});
