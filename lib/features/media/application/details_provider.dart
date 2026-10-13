import 'dart:async';
import 'dart:math';

import 'dart:developer' as developer;
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

// One title's history row. A title is id + type: a movie and a show can
// share a tmdbId (REV-195).
final mediaWatchHistoryProvider = Provider.autoDispose
    .family<AsyncValue<WatchHistory?>, ({String id, String type})>((
      ref,
      title,
    ) {
      final key = '${MediaItem.fromString(title.type).name}-${title.id}';
      return ref.watch(watchHistoryStoreProvider).whenData((map) => map[key]);
    });

// A show's watch logs, with not-yet-saved changes shown at once.
class OptimisticSeriesLogs
    extends AutoDisposeFamilyStreamNotifier<List<WatchLog>, int> {
  // "season-episode" -> the watch count to show until the server has it.
  // A count, not watched / unwatched: removing one of two watches must
  // still show one (REV-192).
  final Map<String, int> _expectedCounts = {};
  List<WatchLog> _serverLogs = const [];

  @override
  Stream<List<WatchLog>> build(int arg) {
    final userId = ref.watch(authProvider).asData?.value?.id;
    if (userId == null) return Stream.value([]);

    final repository = ref.watch(watchHistoryRepositoryProvider);
    return repository
        .watchTitleLogs(userId, arg, 'tv')
        .realtimeErrorsAs(const [])
        .map((list) => _serverLogs = list.map(WatchLog.fromJson).toList())
        .map(_applyOptimisticUpdates);
  }

  /// Shows an episode with [change] applied to its shown watch count
  /// (e.g. `(n) => n - 1` for "remove one") until the server agrees.
  void changeEpisodeCount(
    int season,
    int episode,
    int Function(int shown) change,
  ) {
    final shown = (state.valueOrNull ?? _serverLogs)
        .where((l) => l.season == season && l.episode == episode)
        .length;
    _expectedCounts['$season-$episode'] = max(0, change(shown));
    // Always applied to the server list: the shown one already has them.
    state = AsyncValue.data(_applyOptimisticUpdates(_serverLogs));
  }

  /// Drops the pending changes of [episodes] only (their save failed), so
  /// other episodes still saving keep theirs (REV-196).
  void forgetEpisodeChanges(Iterable<({int season, int episode})> episodes) {
    for (final ep in episodes) {
      _expectedCounts.remove('${ep.season}-${ep.episode}');
    }
    state = AsyncValue.data(_applyOptimisticUpdates(_serverLogs));
  }

  List<WatchLog> _applyOptimisticUpdates(List<WatchLog> serverLogs) {
    final serverCounts = <String, int>{};
    for (final l in serverLogs) {
      final key = '${l.season}-${l.episode}';
      serverCounts[key] = (serverCounts[key] ?? 0) + 1;
    }
    // Confirmed by the server: nothing left to fake.
    _expectedCounts.removeWhere(
      (key, count) => (serverCounts[key] ?? 0) == count,
    );

    final updatedLogs = List<WatchLog>.from(serverLogs);
    _expectedCounts.forEach((key, expected) {
      final [s, e] = key.split('-').map(int.parse).toList();
      final extra = (serverCounts[key] ?? 0) - expected;
      // Hide the newest logs (the ones being removed), or add fake ones.
      final hidden =
          (updatedLogs.where((l) => l.season == s && l.episode == e).toList()
                ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt)))
              .take(max(0, extra))
              .toSet();
      updatedLogs.removeWhere(hidden.contains);
      for (var i = 0; i < -extra; i++) {
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
          .realtimeErrorsAs(const {});
    });

// StateNotifier for managing movie logs with optimistic updates
class OptimisticMovieLogs
    extends AutoDisposeFamilyStreamNotifier<List<WatchLog>, int> {
  // Sets of normalized "logged_at" strings to manage additions and removals
  final Set<String> _optimisticAdditions = {};
  final Set<String> _optimisticRemovals = {};
  List<WatchLog> _serverLogs = const [];

  @override
  Stream<List<WatchLog>> build(int arg) {
    final userId = ref.watch(authProvider).asData?.value?.id;
    if (userId == null) return Stream.value([]);

    final repository = ref.watch(watchHistoryRepositoryProvider);
    return repository
        .watchTitleLogs(userId, arg, 'movie')
        .realtimeErrorsAs(const [])
        .map((list) => _serverLogs = list.map(WatchLog.fromJson).toList())
        .map(_applyOptimisticUpdates);
  }

  void addOptimisticLog(DateTime loggedAt) {
    final normalized = WatchLog.timestampKey(loggedAt);
    _optimisticRemovals.remove(normalized);
    _optimisticAdditions.add(normalized);
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

  /// Hides the logs the server has now, not later ones: a watch logged
  /// after "Delete all" must show (REV-193).
  void optimisticClearAll() {
    _optimisticAdditions.clear();
    _optimisticRemovals.addAll(
      _serverLogs.map((l) => WatchLog.timestampKey(l.loggedAt)),
    );
    _forceRebuild();
  }

  void clearOptimisticUpdates() {
    _optimisticAdditions.clear();
    _optimisticRemovals.clear();
    ref.invalidateSelf();
  }

  // Always applied to the server list: the shown one already has them.
  void _forceRebuild() {
    if (!state.hasValue) return;
    state = AsyncValue.data(_applyOptimisticUpdates(_serverLogs));
  }

  List<WatchLog> _applyOptimisticUpdates(List<WatchLog> currentLogs) {
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

/// Whether the user is watching a title again: a movie with a logged watch,
/// or a show whose highest logged episode is past the current one.
/// Keyed by values, not a [WatchHistory]: the history stream makes new
/// objects on every save, and each one would start a new query (REV-194).
final isRewatchingProvider = FutureProvider.autoDispose
    .family<
      bool,
      ({int tmdbId, MediaKind mediaType, int? season, int? episode})
    >((ref, title) async {
      if (title.mediaType == MediaKind.movie) {
        return ref.watch(movieWatchCountProvider(title.tmdbId)) > 0;
      }

      final userId = ref.watch(authProvider).valueOrNull?.id;
      if (userId == null) return false;

      final highest = await ref
          .watch(watchHistoryRepositoryProvider)
          .getHighestLoggedEpisode(userId, title.tmdbId);
      if (highest == null) return false;

      final season = title.season ?? 0;
      return highest.season > season ||
          (highest.season == season && highest.episode > (title.episode ?? 0));
    });
