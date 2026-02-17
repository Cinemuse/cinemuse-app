import 'package:cinemuse_app/core/services/tmdb_service.dart';
import 'package:cinemuse_app/features/media/application/store/watch_history_store.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/services/supabase_service.dart';
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

// Family state provider for the currently selected season number of a specific series
final selectedSeasonProvider = StateProvider.family<int, String>((ref, mediaId) => 1);

// Family provider to fetch watch history for a specific media item (Derived from Store)
final mediaWatchHistoryProvider = Provider.family<AsyncValue<WatchHistory?>, String>((ref, tmdbId) {
  final store = ref.watch(watchHistoryStoreProvider);
  return store.whenData((map) => map[tmdbId]);
});

// Stream all watch logs for a specific series to track episodic history
final seriesWatchLogsProvider = StreamProvider.family<List<Map<String, dynamic>>, int>((ref, tmdbId) {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return Stream.value([]);
  
  final repository = ref.watch(watchHistoryRepositoryProvider);
  return repository.watchSeriesLogs(userId, tmdbId);
});

// Helper provider to get a map of "season-episode" -> watch_count for the series
final watchedEpisodesMapProvider = Provider.family<Map<String, int>, int>((ref, tmdbId) {
  final logsAsync = ref.watch(seriesWatchLogsProvider(tmdbId));
  return logsAsync.maybeWhen(
    data: (logs) {
      final counts = <String, int>{};
      for (final log in logs) {
        final s = log['season'];
        final e = log['episode'];
        if (s != null && e != null) {
          final key = '$s-$e';
          counts[key] = (counts[key] ?? 0) + 1;
        }
      }
      return counts;
    },
    orElse: () => <String, int>{},
  );
});
// Helper provider to get global series watch status
final seriesWatchStatusProvider = Provider.family<({bool isFullyWatched, bool isPartiallyWatched, int minWatchCount}), ({int tmdbId, int totalEpisodes})>((ref, args) {
  final counts = ref.watch(watchedEpisodesMapProvider(args.tmdbId));
  if (counts.isEmpty) return (isFullyWatched: false, isPartiallyWatched: false, minWatchCount: 0);

  int watchedInSeries = 0;
  int minCount = -1;

  counts.forEach((key, count) {
    if (count > 0) {
      watchedInSeries++;
      if (minCount == -1 || count < minCount) {
        minCount = count;
      }
    }
  });

  final isFullyWatched = watchedInSeries >= args.totalEpisodes;
  final isPartiallyWatched = watchedInSeries > 0 && !isFullyWatched;

  return (
    isFullyWatched: isFullyWatched,
    isPartiallyWatched: isPartiallyWatched,
    minWatchCount: isFullyWatched ? (minCount == -1 ? 0 : minCount) : 0,
  );
});
