import 'package:cinemuse_app/core/services/tmdb_service.dart';
import 'package:cinemuse_app/features/media/application/watch_history_store.dart';
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
final selectedSeasonProvider = StateProvider.family<int, String>((ref, mediaId) {
  // We want to default to the season of the next unwatched episode (or resume point).
  // But we can't easily access async watchHistory here without potential loops or waiting.
  // However, we can use `ref.watch(mediaWatchHistoryProvider(mediaId))` BUT that might not be ready.
  // A better approach: Initialize this provider with 1, but in the UI (MediaDetailsScreen),
  // use a `useEffect` or `listen` to update this provider once history is loaded.
  // OR, we can make this provider depend on history? but then it's not a simple StateProvider for UI toggling.
  // Let's keep it as StateProvider(1) and handle the "initial set" in the Widget.
  return 1;
});

// Family provider to fetch watch history for a specific media item (Derived from Store)
final mediaWatchHistoryProvider = Provider.family<AsyncValue<WatchHistory?>, String>((ref, tmdbId) {
  final store = ref.watch(watchHistoryStoreProvider);
  return store.whenData((map) => map[tmdbId]);
});

// StateNotifier for managing series logs with optimistic updates
class OptimisticSeriesLogs extends FamilyStreamNotifier<List<Map<String, dynamic>>, int> {
  // Store local optimistic updates: 'season-episode' -> isWatched (true=add, false=remove)
  // We use a map to handle multiple rapid updates
  final Map<String, bool> _optimisticUpdates = {};

  @override
  Stream<List<Map<String, dynamic>>> build(int arg) {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value([]);
    
    final repository = ref.watch(watchHistoryRepositoryProvider);
    return repository.watchSeriesLogs(userId, arg);
  }

  // Apply an optimistic update
  void addOptimisticUpdate(int season, int episode, bool isWatched) {
    final key = '$season-$episode';
    _optimisticUpdates[key] = isWatched;
    
    // Force a rebuild with current state + optimistic changes
    state = state.whenData((logs) => _applyOptimisticUpdates(logs));
  }

  // Clear optimistic updates (usually after a successful server sync or error)
  void clearOptimisticUpdates() {
    _optimisticUpdates.clear();
    // Revert to original stream state (or let stream update naturally)
    ref.invalidateSelf();
  }

  List<Map<String, dynamic>> _applyOptimisticUpdates(List<Map<String, dynamic>> currentLogs) {
    // Create a mutable copy
    final List<Map<String, dynamic>> updatedLogs = List.from(currentLogs);
    final Set<String> currentKeys = currentLogs
        .map((l) => '${l['season']}-${l['episode']}')
        .toSet();

    _optimisticUpdates.forEach((key, isWatched) {
      final parts = key.split('-');
      final s = int.parse(parts[0]);
      final e = int.parse(parts[1]);
      
      if (isWatched) {
        // optimistically add log if not present
        if (!currentKeys.contains(key)) {
          updatedLogs.add({
            'season': s,
            'episode': e,
            'media_type': 'tv',
            'logged_at': DateTime.now().toIso8601String(), // Temporary timestamp
            'is_optimistic': true,
          });
          currentKeys.add(key);
        }
      } else {
        // optimistically remove log
        updatedLogs.removeWhere((l) => l['season'] == s && l['episode'] == e);
        currentKeys.remove(key);
      }
    });

    return updatedLogs;
  }
}

// Provider for the optimistic logs
final seriesWatchLogsProvider = StreamNotifierProvider.family<OptimisticSeriesLogs, List<Map<String, dynamic>>, int>(() {
  return OptimisticSeriesLogs();
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

// Helper provider to get a map of "season-episode" -> WatchHistory (progress) for the series
final episodeProgressMapProvider = StreamProvider.family<Map<String, WatchHistory>, int>((ref, tmdbId) {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return Stream.value({});

  final repository = ref.watch(watchHistoryRepositoryProvider);
  return repository.watchSeriesHistory(userId, tmdbId).map((historyList) {
    final map = <String, WatchHistory>{};
    for (final h in historyList) {
      if (h.season != null && h.episode != null) {
        map['${h.season}-${h.episode}'] = h;
      }
    }
    return map;
  });
});
