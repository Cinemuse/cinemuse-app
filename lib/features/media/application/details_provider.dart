import 'package:cinemuse_app/core/application/l10n_provider.dart';
import 'package:cinemuse_app/core/error/app_exception.dart';
import 'package:cinemuse_app/core/error/supabase_error_handler.dart';
import 'package:cinemuse_app/core/error/supabase_extensions.dart';
import 'package:cinemuse_app/core/services/media/tmdb_service.dart';
import 'package:cinemuse_app/features/media/application/watch_history_store.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Family provider to fetch basic details for a specific media item (with local caching)
final mediaItemProvider = FutureProvider.family<MediaItem?, ({int id, MediaKind type})>((ref, args) async {
  final repo = ref.read(mediaRepositoryProvider);
  
  // 1. Check local cache (Memory/Drift)
  final cached = await repo.getMediaItem(args.id, args.type);
  if (cached != null) return cached;

  final connectivity = ref.watch(connectivityProvider).valueOrNull;
  if (connectivity == ConnectivityResult.none) return null;

  // 2. Fetch from TMDB
  final tmdbService = ref.read(tmdbServiceProvider);
  final details = await tmdbService.getMediaDetails(args.id.toString(), args.type.name);
  
  if (details != null) {
     final item = MediaItem.fromTmdbDetails(details, args.type);
     await repo.saveMediaItem(item);
     return item;
  }
  
  return null;
});

// Family provider to fetch full details for a specific media item (e.g. for details screen)
final mediaDetailsProvider = FutureProvider.family<Map<String, dynamic>?, ({String id, String type})>((ref, args) async {
  final connectivity = ref.watch(connectivityProvider).valueOrNull;
  if (connectivity == ConnectivityResult.none) return null;

  final tmdbService = ref.read(tmdbServiceProvider);
  final repo = ref.read(mediaRepositoryProvider);
  final type = MediaItem.fromString(args.type);
  
  try {
    final details = await tmdbService.getMediaDetails(args.id, args.type);
    
    if (details != null) {
      // Opportunistically update cache with full details
      final item = MediaItem.fromTmdbDetails(details, type);
      repo.saveMediaItem(item).catchError((_) {});
    }
    
    return details;
  } catch (_) {
    return null;
  }
});

// Family provider to fetch season details
final seasonDetailsProvider = FutureProvider.family<Map<String, dynamic>?, ({int tmdbId, int seasonNumber})>((ref, args) async {
  final connectivity = ref.watch(connectivityProvider).valueOrNull;
  if (connectivity == ConnectivityResult.none) return null;

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
    final userId = ref.watch(authProvider).asData?.value?.id;
    if (userId == null) return Stream.value([]);
    
    final repository = ref.watch(watchHistoryRepositoryProvider);
    return repository.watchSeriesLogs(userId, arg).handleError((error) {
      if (error is AppException && error.type == AppExceptionType.realtime) {
        return <Map<String, dynamic>>[];
      }
      throw error;
    });
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
  final userId = ref.watch(authProvider).asData?.value?.id;
  if (userId == null) return Stream.value({});

  final repository = ref.watch(watchHistoryRepositoryProvider);
  return repository.watchSeriesHistory(userId, tmdbId).withErrorHandling().map((historyList) {
    final map = <String, WatchHistory>{};
    for (final h in historyList) {
      if (h.season != null && h.episode != null) {
        map['${h.season}-${h.episode}'] = h;
      }
    }
    return map;
  }).handleError((error) {
    if (error is AppException && error.type == AppExceptionType.realtime) {
      return <String, WatchHistory>{};
    }
    throw error;
  });
});

// StateNotifier for managing movie logs with optimistic updates
class OptimisticMovieLogs extends FamilyStreamNotifier<List<Map<String, dynamic>>, int> {
  // Key: logged_at ISO string -> isWatched (always true for additions here)
  final Map<String, bool> _optimisticUpdates = {};
  int _optimisticRemovals = 0;

  @override
  Stream<List<Map<String, dynamic>>> build(int arg) {
    final userId = ref.watch(authProvider).asData?.value?.id;
    if (userId == null) return Stream.value([]);
    
    final repository = ref.watch(watchHistoryRepositoryProvider);
    return repository.watchMovieLogs(userId, arg).handleError((error) {
      if (error is AppException && error.type == AppExceptionType.realtime) {
        return <Map<String, dynamic>>[];
      }
      throw error;
    }).map((logs) => _applyOptimisticUpdates(logs));
  }

  void addOptimisticLog(String loggedAt) {
    _optimisticUpdates[loggedAt] = true;
    _forceRebuild();
  }

  void removeOptimisticLog() {
    _optimisticRemovals++;
    _forceRebuild();
  }

  void _forceRebuild() {
    if (state.hasValue) {
      state = AsyncValue.data(_applyOptimisticUpdates(state.value!));
    }
  }

  void clearOptimisticOffset() {
    _optimisticRemovals = 9999;
    _forceRebuild();
  }

  void clearOptimisticUpdates() {
    _optimisticUpdates.clear();
    _optimisticRemovals = 0;
    ref.invalidateSelf();
  }

  List<Map<String, dynamic>> _applyOptimisticUpdates(List<Map<String, dynamic>> currentLogs) {
    final updatedLogs = List<Map<String, dynamic>>.from(currentLogs);
    final Set<String> currentKeys = currentLogs
        .map((l) => l['logged_at'] as String? ?? '')
        .toSet();

    // 1. Additions: Only add if not already in the stream with the same timestamp
    _optimisticUpdates.forEach((loggedAt, _) {
      if (!currentKeys.contains(loggedAt)) {
        updatedLogs.add({
          'media_type': 'movie',
          'logged_at': loggedAt,
          'is_optimistic': true,
        });
        currentKeys.add(loggedAt);
      }
    });

    // 2. Removals: Hide the latest logs
    if (_optimisticRemovals > 0) {
      if (_optimisticRemovals >= 9999) return [];
      
      updatedLogs.sort((a, b) => (b['logged_at'] as String).compareTo(a['logged_at'] as String));
      for (int i = 0; i < _optimisticRemovals && updatedLogs.isNotEmpty; i++) {
        updatedLogs.removeAt(0);
      }
    }

    return updatedLogs;
  }
}

// Provider for the optimistic movie logs
final movieWatchLogsProvider = StreamNotifierProvider.family<OptimisticMovieLogs, List<Map<String, dynamic>>, int>(() {
  return OptimisticMovieLogs();
});

// Helper provider to get global movie watch count
final movieWatchCountProvider = Provider.family<int, int>((ref, tmdbId) {
  final logsAsync = ref.watch(movieWatchLogsProvider(tmdbId));
  return logsAsync.maybeWhen(
    data: (logs) => logs.length,
    orElse: () => 0,
  );
});
