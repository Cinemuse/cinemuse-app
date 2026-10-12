import 'dart:async';

import 'dart:developer' as developer;
import 'package:cinemuse_app/core/error/app_exception.dart';
import 'package:cinemuse_app/core/error/supabase_extensions.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/media/application/watch_history_store.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';

// Basic details of a title: local cache first, then TMDB. Every provider
// here is autoDispose: a title is freed once no screen shows it (REV-191).
final mediaItemProvider = FutureProvider.autoDispose
    .family<MediaItem?, ({int id, MediaKind type})>((ref, args) async {
      // Watched before the first await: the provider may be gone after it.
      final repo = ref.watch(mediaRepositoryProvider);
      final connectivity = ref.watch(connectivityProvider).valueOrNull;
      final tmdbService = ref.watch(tmdbServiceProvider);

      final cached = await repo.getMediaItem(args.id, args.type);
      if (cached != null && cached.hasCompleteTitle('en')) return cached;
      if (connectivity == ConnectivityResult.none) return cached;

      final details = await tmdbService.getMediaDetails(
        args.id.toString(),
        args.type.name,
      );

      if (details != null) {
        final item = MediaItem.fromTmdbDetails(details, args.type);
        await repo.saveMediaItem(item);
        return item;
      }

      return null;
    });

// Family provider to fetch full details for a specific media item (e.g. for details screen)
final mediaDetailsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, ({String id, String type})>((
      ref,
      args,
    ) async {
      final connectivity = ref.watch(connectivityProvider).valueOrNull;
      if (connectivity == ConnectivityResult.none) return null;

      final tmdbService = ref.watch(tmdbServiceProvider);
      final repo = ref.read(mediaRepositoryProvider);
      final type = MediaItem.fromString(args.type);

      try {
        final details = await tmdbService.getMediaDetails(args.id, args.type);

        if (details != null) {
          // Opportunistically update cache with full details
          final item = MediaItem.fromTmdbDetails(details, type);
          // Cache write only: errors are logged, details still load.
          unawaited(
            repo.saveMediaItem(item).catchError((e, stack) {
              developer.log(
                'Failed to opportunistically save media item ${args.id} to cache',
                name: 'detailsProvider',
                error: e,
                stackTrace: stack,
              );
            }),
          );
        }

        return details;
      } catch (e, stack) {
        developer.log(
          'Failed to fetch media details for ${args.id}',
          name: 'detailsProvider',
          error: e,
          stackTrace: stack,
        );
        return null;
      }
    });

/// Strongly-typed provider emitting the rich [MediaItem] with full details (cast, crew, videos, etc.)
final typedMediaDetailsProvider = FutureProvider.autoDispose
    .family<MediaItem?, ({String id, String type})>((ref, args) async {
      final raw = await ref.watch(mediaDetailsProvider(args).future);
      if (raw == null) return null;
      return MediaItem.fromTmdbDetails(raw, MediaItem.fromString(args.type));
    });

final seasonDetailsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, ({int tmdbId, int seasonNumber})>((
      ref,
      args,
    ) async {
      final connectivity = ref.watch(connectivityProvider).valueOrNull;
      if (connectivity == ConnectivityResult.none) return null;

      final tmdbService = ref.watch(tmdbServiceProvider);
      return tmdbService.getSeasonDetails(args.tmdbId, args.seasonNumber);
    });

final collectionDetailsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, int>((ref, collectionId) async {
      final connectivity = ref.watch(connectivityProvider).valueOrNull;
      if (connectivity == ConnectivityResult.none) return null;

      final tmdbService = ref.watch(tmdbServiceProvider);
      return tmdbService.getCollectionDetails(collectionId);
    });

// Family provider to fetch strongly-typed collection domain model
final collectionModelProvider = FutureProvider.autoDispose
    .family<MediaCollection?, int>((ref, collectionId) async {
      final raw = await ref.watch(
        collectionDetailsProvider(collectionId).future,
      );
      if (raw == null) return null;
      return MediaCollection.fromTmdbMap(raw);
    });

// Notifier for the currently selected season number of a specific series
class SelectedSeasonNotifier extends AutoDisposeFamilyNotifier<int, String> {
  @override
  int build(String arg) => 1;

  void selectSeason(int season) {
    state = season;
  }
}

final selectedSeasonProvider = NotifierProvider.autoDispose
    .family<SelectedSeasonNotifier, int, String>(SelectedSeasonNotifier.new);

// Family provider to fetch watch history for a specific media item (Derived from Store)
final mediaWatchHistoryProvider = Provider.autoDispose
    .family<AsyncValue<WatchHistory?>, String>((ref, tmdbId) {
      final store = ref.watch(watchHistoryStoreProvider);
      return store.whenData((map) => map[tmdbId]);
    });

// StateNotifier for managing series logs with optimistic updates
class OptimisticSeriesLogs
    extends AutoDisposeFamilyStreamNotifier<List<WatchLog>, int> {
  // Key: "season-episode" -> true (added), false (removed)
  final Map<String, bool> _optimisticUpdates = {};

  @override
  Stream<List<WatchLog>> build(int arg) {
    final userId = ref.watch(authProvider).asData?.value?.id;
    if (userId == null) return Stream.value([]);

    final repository = ref.watch(watchHistoryRepositoryProvider);
    return repository
        .watchTitleLogs(userId, arg, 'tv')
        .handleError((error) {
          if (error is AppException &&
              error.type == AppExceptionType.realtime) {
            return <Map<String, dynamic>>[];
          }
          throw error;
        })
        .map((list) => list.map(WatchLog.fromJson).toList())
        .map(_applyOptimisticUpdates);
  }

  void addOptimisticUpdate(int season, int episode, bool isWatched) {
    final key = '$season-$episode';
    _optimisticUpdates[key] = isWatched;
    _forceRebuild();
  }

  void _forceRebuild() {
    state.whenData((logs) {
      state = AsyncValue.data(_applyOptimisticUpdates(logs));
    });
  }

  void clearOptimisticUpdates() {
    _optimisticUpdates.clear();
    ref.invalidateSelf();
  }

  List<WatchLog> _applyOptimisticUpdates(List<WatchLog> currentLogs) {
    // 0. Build current server state map
    final Set<String> serverKeys = currentLogs
        .map((l) => '${l.season}-${l.episode}')
        .toSet();

    // 1. Self-Cleaning: Prune confirmed changes from the local map
    _optimisticUpdates.removeWhere((key, isWatched) {
      final exists = serverKeys.contains(key);
      return (isWatched && exists) || (!isWatched && !exists);
    });

    final List<WatchLog> updatedLogs = List.from(currentLogs);
    final Set<String> activeKeys = Set.from(serverKeys);

    // 2. Apply remaining optimistic updates that aren't on the server yet
    _optimisticUpdates.forEach((key, isWatched) {
      final parts = key.split('-');
      final s = int.parse(parts[0]);
      final e = int.parse(parts[1]);

      if (isWatched) {
        if (!activeKeys.contains(key)) {
          updatedLogs.add(
            WatchLog(
              tmdbId: arg,
              season: s,
              episode: e,
              mediaType: MediaKind.tv,
              loggedAt: DateTime.now(),
              isOptimistic: true,
            ),
          );
          activeKeys.add(key);
        }
      } else {
        updatedLogs.removeWhere((l) => l.season == s && l.episode == e);
        activeKeys.remove(key);
      }
    });

    return updatedLogs;
  }
}

final seriesWatchLogsProvider = StreamNotifierProvider.autoDispose
    .family<OptimisticSeriesLogs, List<WatchLog>, int>(() {
      return OptimisticSeriesLogs();
    });

// Helper provider to get a map of "season-episode" -> watch_count for the series
final watchedEpisodesMapProvider = Provider.autoDispose
    .family<Map<String, int>, int>((ref, tmdbId) {
      final logsAsync = ref.watch(seriesWatchLogsProvider(tmdbId));
      return logsAsync.maybeWhen(
        data: (logs) {
          final counts = <String, int>{};
          for (final log in logs) {
            final s = log.season;
            final e = log.episode;
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
final seriesWatchStatusProvider = Provider.autoDispose
    .family<
      ({bool isFullyWatched, bool isPartiallyWatched, int minWatchCount}),
      ({int tmdbId, int totalEpisodes})
    >((ref, args) {
      final counts = ref.watch(watchedEpisodesMapProvider(args.tmdbId));
      if (counts.isEmpty) {
        return (
          isFullyWatched: false,
          isPartiallyWatched: false,
          minWatchCount: 0,
        );
      }

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
final episodeProgressMapProvider = StreamProvider.autoDispose
    .family<Map<String, WatchHistory>, int>((ref, tmdbId) {
      final userId = ref.watch(authProvider).asData?.value?.id;
      if (userId == null) return Stream.value({});

      final repository = ref.watch(watchHistoryRepositoryProvider);
      return repository
          .watchSeriesHistory(userId, tmdbId)
          .withErrorHandling()
          .map((historyList) {
            final map = <String, WatchHistory>{};
            for (final h in historyList) {
              if (h.season != null && h.episode != null) {
                map['${h.season}-${h.episode}'] = h;
              }
            }
            return map;
          })
          .handleError((error) {
            if (error is AppException &&
                error.type == AppExceptionType.realtime) {
              return <String, WatchHistory>{};
            }
            throw error;
          });
    });

// StateNotifier for managing movie logs with optimistic updates
class OptimisticMovieLogs
    extends AutoDisposeFamilyStreamNotifier<List<WatchLog>, int> {
  // Sets of normalized "logged_at" strings to manage additions and removals
  final Set<String> _optimisticAdditions = {};
  final Set<String> _optimisticRemovals = {};
  bool _clearAll = false;

  @override
  Stream<List<WatchLog>> build(int arg) {
    final userId = ref.watch(authProvider).asData?.value?.id;
    if (userId == null) return Stream.value([]);

    final repository = ref.watch(watchHistoryRepositoryProvider);
    return repository
        .watchTitleLogs(userId, arg, 'movie')
        .handleError((error) {
          if (error is AppException &&
              error.type == AppExceptionType.realtime) {
            return <Map<String, dynamic>>[];
          }
          throw error;
        })
        .map((list) => list.map(WatchLog.fromJson).toList())
        .map(_applyOptimisticUpdates);
  }

  void addOptimisticLog(String loggedAt) {
    final date = DateTime.tryParse(loggedAt);
    if (date == null) return;
    final normalized = WatchLog.timestampKey(date);
    _optimisticRemovals.remove(normalized);
    _optimisticAdditions.add(normalized);
    _clearAll = false;
    _forceRebuild();
  }

  void removeOptimisticLog() {
    state.whenData((logs) {
      if (logs.isEmpty) return;

      final sorted = List<WatchLog>.from(logs)
        ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));

      final latest = sorted.first;
      final normalized = WatchLog.timestampKey(latest.loggedAt);

      if (latest.isOptimistic) {
        _optimisticAdditions.remove(normalized);
      } else {
        _optimisticRemovals.add(normalized);
      }
      _forceRebuild();
    });
  }

  void clearOptimisticOffset() {
    _optimisticAdditions.clear();
    _optimisticRemovals.clear();
    _clearAll = true;
    _forceRebuild();
  }

  void clearOptimisticUpdates() {
    _optimisticAdditions.clear();
    _optimisticRemovals.clear();
    _clearAll = false;
    ref.invalidateSelf();
  }

  void _forceRebuild() {
    state.whenData((logs) {
      state = AsyncValue.data(_applyOptimisticUpdates(logs));
    });
  }

  List<WatchLog> _applyOptimisticUpdates(List<WatchLog> currentLogs) {
    if (_clearAll) return [];

    final Set<String> serverKeys = currentLogs
        .map((l) => WatchLog.timestampKey(l.loggedAt))
        .toSet();

    // 1. Self-Cleaning: Prune confirmed entries
    _optimisticAdditions.removeWhere(serverKeys.contains);
    _optimisticRemovals.removeWhere((key) => !serverKeys.contains(key));

    final updatedLogs = List<WatchLog>.from(currentLogs);

    // 2. Hide removals still present in the stream
    updatedLogs.removeWhere(
      (l) => _optimisticRemovals.contains(WatchLog.timestampKey(l.loggedAt)),
    );

    final Set<String> activeKeys = updatedLogs
        .map((l) => WatchLog.timestampKey(l.loggedAt))
        .toSet();

    // 3. Add additions not yet present in the stream
    for (final loggedAtStr in _optimisticAdditions) {
      if (!activeKeys.contains(loggedAtStr)) {
        updatedLogs.add(
          WatchLog(
            tmdbId: arg,
            mediaType: MediaKind.movie,
            loggedAt:
                DateTime.tryParse(loggedAtStr)?.toLocal() ?? DateTime.now(),
            isOptimistic: true,
          ),
        );
        activeKeys.add(loggedAtStr);
      }
    }

    return updatedLogs;
  }
}

final movieWatchLogsProvider = StreamNotifierProvider.autoDispose
    .family<OptimisticMovieLogs, List<WatchLog>, int>(() {
      return OptimisticMovieLogs();
    });

// Helper provider to get global movie watch count
final movieWatchCountProvider = Provider.autoDispose.family<int, int>((
  ref,
  tmdbId,
) {
  final logsAsync = ref.watch(movieWatchLogsProvider(tmdbId));
  return logsAsync.maybeWhen(data: (logs) => logs.length, orElse: () => 0);
});

// Helper provider to determine if a user is actively rewatching
final isRewatchingProvider = FutureProvider.autoDispose.family<bool, WatchHistory>((
  ref,
  history,
) async {
  if (history.mediaType == MediaKind.movie) {
    // If it's a movie and there are logs, it's a rewatch
    final count = ref.watch(movieWatchCountProvider(history.tmdbId));
    return count > 0;
  }

  // For TV, we need to check if highest logged episode is > current tracking pointer
  final authState = ref.read(authProvider).valueOrNull;
  if (authState == null) return false;

  try {
    final maxLog = await ref
        .read(supabaseClientProvider)
        .from('watch_logs')
        .select('season, episode')
        .eq('user_id', authState.id)
        .eq('tmdb_id', history.tmdbId)
        .eq('media_type', 'tv')
        .order('season', ascending: false)
        .order('episode', ascending: false)
        .limit(1)
        .maybeSingle();

    if (maxLog == null) return false;

    final maxS = maxLog['season'] as int? ?? 0;
    final maxE = maxLog['episode'] as int? ?? 0;
    final curS = history.season ?? 0;
    final curE = history.episode ?? 0;

    return maxS > curS || (maxS == curS && maxE > curE);
  } catch (e, stack) {
    developer.log(
      'Failed to query max watch log for series ${history.tmdbId}',
      name: 'isRewatchingProvider',
      error: e,
      stackTrace: stack,
    );
    return false;
  }
});
