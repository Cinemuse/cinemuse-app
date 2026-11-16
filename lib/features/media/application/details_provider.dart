import 'dart:async';
import 'package:cinemuse_app/features/media/data/watch_logs_repository.dart';
import 'dart:math';

import 'dart:developer' as developer;
import 'package:cinemuse_app/core/application/keep_alive_for.dart';
import 'package:cinemuse_app/core/error/supabase_failure.dart';
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
import 'package:cinemuse_app/features/media/domain/media_details_parts.dart';
import 'package:cinemuse_app/features/media/domain/episode_item.dart';

// Basic details of a title: local cache first, then TMDB. Every provider
// here is autoDispose: a title is freed once no screen shows it (REV-191).
final mediaItemProvider = FutureProvider.autoDispose
    .family<MediaItem?, ({int id, MediaKind type})>((ref, args) async {
      // Watched before the first await: the provider may be gone after it.
      final repo = ref.watch(mediaRepositoryProvider);
      final connectivity = ref.watch(connectivityProvider).value;
      final tmdbService = ref.watch(tmdbServiceProvider);

      final cached = await repo.getMediaItem(args.id, args.type);
      // The server's media_cache keeps no rating, so a title cached from it
      // (e.g. synced from another device) still needs TMDB (REV-270).
      if (cached != null &&
          cached.hasCompleteTitle('en') &&
          cached.voteAverage != null) {
        return cached;
      }
      if (connectivity == ConnectivityResult.none) return cached;

      final item = await tmdbService.getMediaDetails(
        args.id.toString(),
        args.type.name,
      );
      if (item != null) await repo.saveMediaItem(item);
      return item;
    });

// A title's full details (cast, crew, videos, seasons…), for the details
// screen.
final mediaDetailsProvider = FutureProvider.autoDispose
    .family<MediaItem?, ({String id, String type})>((ref, args) async {
      final connectivity = ref.watch(connectivityProvider).value;
      if (connectivity == ConnectivityResult.none) return null;

      final tmdbService = ref.watch(tmdbServiceProvider);
      final repo = ref.read(mediaRepositoryProvider);

      try {
        final item = await tmdbService.getMediaDetails(args.id, args.type);

        if (item != null) {
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

        return item;
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

/// A season's episodes; null offline or when TMDB has no such season.
final seasonEpisodesProvider = FutureProvider.autoDispose
    .family<List<EpisodeItem>?, ({int tmdbId, int seasonNumber})>((
      ref,
      args,
    ) async {
      final connectivity = ref.watch(connectivityProvider).value;
      if (connectivity == ConnectivityResult.none) return null;

      final tmdbService = ref.watch(tmdbServiceProvider);
      return tmdbService.getSeasonEpisodes(args.tmdbId, args.seasonNumber);
    });

/// A film collection (a saga) with its films; null offline.
final collectionDetailsProvider = FutureProvider.autoDispose
    .family<MediaCollection?, int>((ref, collectionId) async {
      final connectivity = ref.watch(connectivityProvider).value;
      if (connectivity == ConnectivityResult.none) return null;

      final tmdbService = ref.watch(tmdbServiceProvider);
      return tmdbService.getCollectionDetails(collectionId);
    });

// Notifier for the currently selected season number of a specific series
class SelectedSeasonNotifier extends Notifier<int> {
  // The family key (the series id): one notifier per series.
  SelectedSeasonNotifier(String _);

  @override
  int build() => 1;

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
      return ref.watch(shownWatchHistoryProvider).whenData((map) => map[key]);
    });

// A show's watch logs, with not-yet-saved changes shown at once.
class OptimisticSeriesLogs extends StreamNotifier<List<WatchLog>> {
  OptimisticSeriesLogs(this.tmdbId);

  final int tmdbId;

  // "season-episode" -> the watch count to show until the server has it.
  // A count, not watched / unwatched: removing one of two watches must
  // still show one (REV-192).
  final Map<String, int> _expectedCounts = {};
  List<WatchLog> _serverLogs = const [];
  // The ids of the logs "Remove all" takes away while its Undo message is
  // up: hidden, so the show looks never watched (logs added later show).
  Set<Object?> _hiddenIds = const {};

  @override
  Stream<List<WatchLog>> build() {
    final userId = ref.watch(authProvider).asData?.value?.id;
    if (userId == null) return Stream.value([]);
    ref.keepAliveFor(const Duration(minutes: 5)); // reopen at once (REV-287)

    final repository = ref.watch(watchLogsRepositoryProvider);
    return repository
        .watchTitleLogs(userId, tmdbId, 'tv')
        .realtimeErrorsAs(const [])
        .map((list) => _serverLogs = list.map(WatchLog.fromJson).toList())
        .map(_applyOptimisticUpdates);
  }

  /// Shows an episode with [change] applied to its shown watch count
  /// (e.g. `(n) => n - 1` for "remove one") until the server agrees.
  /// Returns how many watches fewer it shows now (negative when it adds).
  int changeEpisodeCount(
    int season,
    int episode,
    int Function(int shown) change,
  ) {
    final shown = (state.value ?? _serverLogs)
        .where((l) => l.season == season && l.episode == episode)
        .length;
    final expected = max(0, change(shown));
    _expectedCounts['$season-$episode'] = expected;
    // Always applied to the server list: the shown one already has them.
    state = AsyncValue.data(_applyOptimisticUpdates(_serverLogs));
    return shown - expected;
  }

  /// Drops the pending changes of [episodes] only (their save failed), so
  /// other episodes still saving keep theirs (REV-196).
  void forgetEpisodeChanges(Iterable<({int season, int episode})> episodes) {
    for (final ep in episodes) {
      _expectedCounts.remove('${ep.season}-${ep.episode}');
    }
    state = AsyncValue.data(_applyOptimisticUpdates(_serverLogs));
  }

  /// Hides every log saved so far ("Remove all" waiting for its Undo);
  /// episodes marked afterwards still show.
  void hideAllLogs() {
    _hiddenIds = {for (final l in _serverLogs) l.id};
    state = AsyncValue.data(_applyOptimisticUpdates(_serverLogs));
  }

  /// Shows the hidden logs again (Undo, or the removal failed).
  void showAllLogs() {
    _hiddenIds = const {};
    state = AsyncValue.data(_applyOptimisticUpdates(_serverLogs));
  }

  List<WatchLog> _applyOptimisticUpdates(List<WatchLog> serverLogs) {
    if (_hiddenIds.isNotEmpty) {
      serverLogs = [
        for (final l in serverLogs)
          if (!_hiddenIds.contains(l.id)) l,
      ];
    }
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
            tmdbId: tmdbId,
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
    .family<OptimisticSeriesLogs, List<WatchLog>, int>(
      OptimisticSeriesLogs.new,
    );

// Helper provider to get a map of "season-episode" -> watch_count for the series
final watchedEpisodesMapProvider = Provider.autoDispose
    .family<Map<String, int>, int>((ref, tmdbId) {
      final logsAsync = ref.watch(seriesWatchLogsProvider(tmdbId));
      return logsAsync.maybeWhen(
        data: (logs) {
          final counts = <String, int>{};
          for (final log in logs) {
            if (log.season == null || log.episode == null) continue;
            final key = '${log.season}-${log.episode}';
            counts[key] = (counts[key] ?? 0) + 1;
          }
          return counts;
        },
        orElse: () => <String, int>{},
      );
    });

/// A show's watch status; null while its logs first load (REV-287).
final seriesWatchStatusProvider = Provider.autoDispose
    .family<
      ({bool isFullyWatched, bool isPartiallyWatched, int minWatchCount})?,
      ({int tmdbId, int totalEpisodes})
    >((ref, args) {
      final isLoading = ref.watch(
        seriesWatchLogsProvider(args.tmdbId).select(_isFirstLoad),
      );
      if (isLoading) return null;
      final counts = ref.watch(watchedEpisodesMapProvider(args.tmdbId));
      int watchedInSeries = 0;
      int minCount = -1;

      counts.forEach((key, count) {
        // Specials aren't in the aired total either (REV-198).
        if (count > 0 && !key.startsWith('0-')) {
          watchedInSeries++;
          if (minCount == -1 || count < minCount) {
            minCount = count;
          }
        }
      });

      final isFullyWatched =
          watchedInSeries > 0 && watchedInSeries >= args.totalEpisodes;
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
          .withAppFailure()
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

// A movie's watch logs, with not-yet-saved changes shown at once.
class OptimisticMovieLogs extends StreamNotifier<List<WatchLog>> {
  OptimisticMovieLogs(this.tmdbId);

  final int tmdbId;

  // Sets of normalized "logged_at" strings to manage additions and removals
  final Set<String> _optimisticAdditions = {};
  final Set<String> _optimisticRemovals = {};
  List<WatchLog> _serverLogs = const [];

  @override
  Stream<List<WatchLog>> build() {
    final userId = ref.watch(authProvider).asData?.value?.id;
    if (userId == null) return Stream.value([]);
    ref.keepAliveFor(const Duration(minutes: 5)); // reopen at once (REV-287)

    final repository = ref.watch(watchLogsRepositoryProvider);
    return repository
        .watchTitleLogs(userId, tmdbId, 'movie')
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

  /// Hides the newest log. Returns what it hid, for [showLogsAgain]
  /// (nothing when it was a watch not saved yet).
  Set<String> removeOptimisticLog() {
    final logs = state.asData?.value;
    if (logs == null || logs.isEmpty) return const {};

    final sorted = List<WatchLog>.from(logs)
      ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));

    final latest = sorted.first;
    final normalized = WatchLog.timestampKey(latest.loggedAt);

    final Set<String> hidden;
    if (latest.isOptimistic) {
      _optimisticAdditions.remove(normalized);
      hidden = const {};
    } else {
      _optimisticRemovals.add(normalized);
      hidden = {normalized};
    }
    _forceRebuild();
    return hidden;
  }

  /// Hides the logs the server has now, not later ones: a watch logged
  /// after "Delete all" must show (REV-193). Returns what it hid, for
  /// [showLogsAgain].
  Set<String> optimisticClearAll() {
    _optimisticAdditions.clear();
    final hidden = {
      for (final l in _serverLogs) WatchLog.timestampKey(l.loggedAt),
    };
    _optimisticRemovals.addAll(hidden);
    _forceRebuild();
    return hidden;
  }

  /// Shows again the logs a removal hid (its Undo, or it failed).
  void showLogsAgain(Set<String> hidden) {
    _optimisticRemovals.removeAll(hidden);
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
            tmdbId: tmdbId,
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
    .family<OptimisticMovieLogs, List<WatchLog>, int>(OptimisticMovieLogs.new);

bool _isFirstLoad(AsyncValue<Object?> v) => v.isLoading && !v.hasValue;

/// Times a movie was watched; null while its logs first load (REV-287).
final movieWatchCountProvider = Provider.autoDispose.family<int?, int>((
  ref,
  tmdbId,
) {
  final logsAsync = ref.watch(movieWatchLogsProvider(tmdbId));
  if (_isFirstLoad(logsAsync)) return null;
  return logsAsync.value?.length ?? 0;
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
        return (ref.watch(movieWatchCountProvider(title.tmdbId)) ?? 0) > 0;
      }

      final userId = ref.watch(authProvider).value?.id;
      if (userId == null) return false;

      final highest = await ref
          .watch(watchLogsRepositoryProvider)
          .getHighestLoggedEpisode(userId, title.tmdbId);
      if (highest == null) return false;

      final season = title.season ?? 0;
      return highest.season > season ||
          (highest.season == season && highest.episode > (title.episode ?? 0));
    });
