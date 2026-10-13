import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/home/application/home_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cinemuse_app/features/media/domain/watch_history.dart';

/// Controller for Media Details logic.
/// Centralizes actions like tracking, list management, and state updates.
class MediaDetailsController extends AutoDisposeNotifier<void> {
  @override
  void build() {}

  WatchHistoryRepository get _repository =>
      ref.read(watchHistoryRepositoryProvider);
  String? get _userId => ref.read(supabaseClientProvider).auth.currentUser?.id;

  /// The season the details screen opens on: the history's season, or the
  /// next one when that season is fully watched. Only reads: opening a page
  /// must not change Continue Watching (REV-190). Logging an episode already
  /// moves the show on, and the agenda brings it back for a new season.
  int resolveInitialSeason({
    required int tmdbId,
    required Map<String, dynamic> details,
    required WatchHistory? watchHistory,
  }) {
    if (watchHistory == null ||
        watchHistory.season == null ||
        watchHistory.season! <= 0) {
      return 1;
    }

    int targetSeason = watchHistory.season!;
    final seasonData = (details['seasons'] as List?)?.firstWhere(
      (s) => s['season_number'] == targetSeason,
      orElse: () => null,
    );

    if (seasonData != null) {
      final episodeCount = seasonData['episode_count'] as int? ?? 0;
      final watchedEpisodesMap = ref.read(watchedEpisodesMapProvider(tmdbId));

      bool isSeasonCompleted = episodeCount > 0;
      for (int i = 1; i <= episodeCount; i++) {
        if ((watchedEpisodesMap['$targetSeason-$i'] ?? 0) == 0) {
          isSeasonCompleted = false;
          break;
        }
      }

      if (isSeasonCompleted) {
        final nextSeasonData = (details['seasons'] as List?)?.firstWhere(
          (s) => s['season_number'] == targetSeason + 1,
          orElse: () => null,
        );

        if (nextSeasonData != null) targetSeason++;
      }
    }
    return targetSeason;
  }

  /// Logs a single episode watch (see [logMultipleEpisodes]).
  Future<void> logEpisodeWatch({
    required int tmdbId,
    required int season,
    required int episode,
    DateTime? loggedAt,
  }) => logMultipleEpisodes(
    tmdbId: tmdbId,
    episodes: [(season: season, episode: episode)],
    loggedAt: loggedAt,
  );

  /// Deletes the latest log for an episode.
  Future<void> deleteLatestEpisodeLog({
    required int tmdbId,
    required int season,
    required int episode,
  }) async {
    final userId = _userId;
    if (userId == null) return;

    ref
        .read(seriesWatchLogsProvider(tmdbId).notifier)
        .changeEpisodeCount(season, episode, (shown) => shown - 1);

    try {
      await _repository.deleteLatestEpisodeLog(
        userId: userId,
        tmdbId: tmdbId,
        season: season,
        episode: episode,
      );
      // An undo can turn a dropped show back into "watching" (REV-226).
      ref.invalidate(droppedListProvider);
      ref.invalidate(continueWatchingProvider);
    } catch (e, stack) {
      _rollbackSeriesOptimistic(
        tmdbId,
        [(season: season, episode: episode)],
        'deleteLatestEpisodeLog',
        e,
        stack,
      );
      rethrow;
    }
  }

  /// Deletes all logs for a specific episode.
  Future<void> deleteAllEpisodeLogs({
    required int tmdbId,
    required int season,
    required int episode,
  }) async {
    final userId = _userId;
    if (userId == null) return;

    ref
        .read(seriesWatchLogsProvider(tmdbId).notifier)
        .changeEpisodeCount(season, episode, (_) => 0);

    try {
      await _repository.deleteAllEpisodeLogs(
        userId: userId,
        tmdbId: tmdbId,
        season: season,
        episode: episode,
      );
      ref.invalidate(droppedListProvider);
      ref.invalidate(continueWatchingProvider);
    } catch (e, stack) {
      _rollbackSeriesOptimistic(
        tmdbId,
        [(season: season, episode: episode)],
        'deleteAllEpisodeLogs',
        e,
        stack,
      );
      rethrow;
    }
  }

  /// Logs episodes (one tick, mark season / all) and moves Continue Watching
  /// on to the next episode, in one server call.
  Future<void> logMultipleEpisodes({
    required int tmdbId,
    required List<({int season, int episode})> episodes,
    DateTime? loggedAt,
  }) async {
    final userId = _userId;
    if (userId == null) return;

    final notifier = ref.read(seriesWatchLogsProvider(tmdbId).notifier);
    for (final ep in episodes) {
      notifier.changeEpisodeCount(ep.season, ep.episode, (shown) => shown + 1);
    }

    try {
      await _repository.logMultipleEpisodes(
        userId: userId,
        tmdbId: tmdbId,
        episodes: episodes,
        seriesDetails: await _loadSeriesDetails(tmdbId),
        loggedAt: loggedAt,
      );
      // A dropped show becomes "watching" again (REV-227).
      ref.invalidate(droppedListProvider);
    } catch (e, stack) {
      _rollbackSeriesOptimistic(
        tmdbId,
        episodes,
        'logMultipleEpisodes',
        e,
        stack,
      );
      rethrow;
    }
  }

  /// The show's TMDB details (needed to pick the next episode), taken from
  /// the details page when it's open instead of downloading them again
  /// (REV-196); that provider also saves them to the media cache.
  Future<Map<String, dynamic>?> _loadSeriesDetails(int tmdbId) async {
    final details = await ref.read(
      mediaDetailsProvider((id: '$tmdbId', type: 'tv')).future,
    );
    if (details == null) {
      // Safe to go on: the episodes still get logged, Continue Watching just
      // stays on the highest marked one instead of the next.
      AppLogger.warn(
        'MediaDetailsController',
        'Could not load series $tmdbId to find the next episode',
      );
    }
    return details;
  }

  /// Deletes all logs for a series.
  Future<void> deleteAllSeriesLogs({required int tmdbId}) async {
    final userId = _userId;
    if (userId == null) return;

    // Not optimistic: the shown episodes reload once the server confirms.
    await _repository.deleteAllSeriesLogs(userId: userId, tmdbId: tmdbId);
    ref.invalidate(droppedListProvider);
    ref.invalidate(continueWatchingProvider);
  }

  Future<void> logMovieWatch({required int tmdbId, DateTime? loggedAt}) async {
    final userId = _userId;
    if (userId == null) return;

    // The app's own "now" (not the server's) so the optimistic log matches the
    // saved one.
    final now = loggedAt ?? DateTime.now();

    ref.read(movieWatchLogsProvider(tmdbId).notifier).addOptimisticLog(now);

    try {
      await _repository.logMovieWatch(
        userId: userId,
        tmdbId: tmdbId,
        loggedAt: now,
        isNow: loggedAt == null,
      );
      // The logs stream and the optimistic logic update the logs; the Dropped
      // list is a one-off load, and a dropped movie is now completed (REV-228).
      ref.invalidate(droppedListProvider);
    } catch (e, stack) {
      _rollbackMovieOptimistic(tmdbId, 'logMovieWatch', e, stack);
      rethrow;
    }
  }

  Future<void> deleteLatestMovieLog({required int tmdbId}) async {
    final userId = _userId;
    if (userId == null) return;

    ref.read(movieWatchLogsProvider(tmdbId).notifier).removeOptimisticLog();

    try {
      await _repository.deleteLatestMovieLog(userId: userId, tmdbId: tmdbId);
      ref.invalidate(droppedListProvider);
      ref.invalidate(continueWatchingProvider);
    } catch (e, stack) {
      _rollbackMovieOptimistic(tmdbId, 'deleteLatestMovieLog', e, stack);
      rethrow;
    }
  }

  Future<void> deleteAllMovieLogs({required int tmdbId}) async {
    final userId = _userId;
    if (userId == null) return;

    ref.read(movieWatchLogsProvider(tmdbId).notifier).optimisticClearAll();

    try {
      await _repository.deleteAllMovieLogs(userId: userId, tmdbId: tmdbId);
      ref.invalidate(droppedListProvider);
      ref.invalidate(continueWatchingProvider);
    } catch (e, stack) {
      _rollbackMovieOptimistic(tmdbId, 'deleteAllMovieLogs', e, stack);
      rethrow;
    }
  }

  void _rollbackSeriesOptimistic(
    int tmdbId,
    List<({int season, int episode})> episodes,
    String action,
    Object error,
    StackTrace stack,
  ) {
    AppLogger.error(
      'MediaDetailsController',
      'Failed $action for series $tmdbId',
      error: error,
      stackTrace: stack,
    );
    ref
        .read(seriesWatchLogsProvider(tmdbId).notifier)
        .forgetEpisodeChanges(episodes);
  }

  void _rollbackMovieOptimistic(
    int tmdbId,
    String action,
    Object error,
    StackTrace stack,
  ) {
    AppLogger.error(
      'MediaDetailsController',
      'Failed $action for movie $tmdbId',
      error: error,
      stackTrace: stack,
    );
    ref.read(movieWatchLogsProvider(tmdbId).notifier).clearOptimisticUpdates();
  }
}

final mediaDetailsControllerProvider =
    AutoDisposeNotifierProvider<MediaDetailsController, void>(() {
      return MediaDetailsController();
    });
