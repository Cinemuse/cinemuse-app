import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/features/media/data/watch_logs_repository.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/home/application/continue_watching_service.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/application/title_removals.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/media/application/series_domain_service_provider.dart';

/// Controller for Media Details logic.
/// Centralizes actions like tracking, list management, and state updates.
class MediaDetailsController extends Notifier<void> {
  @override
  void build() {}

  WatchLogsRepository get _repository => ref.read(watchLogsRepositoryProvider);
  String? get _userId => ref.read(supabaseClientProvider).auth.currentUser?.id;
  TitleRemovals get _removals => ref.read(titleRemovalsProvider);

  /// The season the details screen opens on: the history's season, or the
  /// next one when that season is fully watched. Only reads: opening a page
  /// must not change Continue Watching (REV-190). Logging an episode already
  /// moves the show on, and the agenda brings it back for a new season.
  int resolveInitialSeason({
    required int tmdbId,
    required MediaItem series,
    required WatchHistory? watchHistory,
  }) {
    if (watchHistory == null ||
        watchHistory.season == null ||
        watchHistory.season! <= 0) {
      return 1;
    }

    int targetSeason = watchHistory.season!;
    final seasons = series.seasons ?? const [];
    final seasonData = seasons
        .where((s) => s.seasonNumber == targetSeason)
        .firstOrNull;

    if (seasonData != null) {
      final episodeCount = seasonData.episodeCount ?? 0;
      final watchedEpisodesMap = ref.read(watchedEpisodesMapProvider(tmdbId));

      bool isSeasonCompleted = episodeCount > 0;
      for (int i = 1; i <= episodeCount; i++) {
        if ((watchedEpisodesMap['$targetSeason-$i'] ?? 0) == 0) {
          isSeasonCompleted = false;
          break;
        }
      }

      if (isSeasonCompleted &&
          seasons.any((s) => s.seasonNumber == targetSeason + 1)) {
        targetSeason++;
      }
    }
    return targetSeason;
  }

  /// Moves the title to Dropped. Throws an [AppFailure].
  Future<void> dropTitle(WatchHistory history) =>
      ref.read(continueWatchingServiceProvider).drop(history);

  /// Clears the resume point ("Clear progress") unless [undone] completes
  /// with true. Throws an [AppFailure].
  Future<void> clearProgress(
    WatchHistory history, {
    required Future<bool> undone,
  }) => ref
      .read(continueWatchingServiceProvider)
      .clearProgress(history, undone: undone);

  /// Takes a dropped title out of Dropped (pressing Play on it). Does
  /// nothing if it isn't dropped. Throws an [AppFailure].
  Future<void> restoreIfDropped(int tmdbId, MediaKind mediaType) async {
    final dropped = ref.read(droppedListProvider).value;
    if (dropped?.containsTitle(tmdbId, mediaType) != true) return;
    await ref
        .read(userListsProvider.notifier)
        .restoreFromDropped(tmdbId, mediaType);
  }

  /// Logs every aired episode, or only the unwatched ones with
  /// [onlyRemaining] (the series "mark all" sheet).
  Future<void> markAllEpisodes({
    required int tmdbId,
    required MediaItem series,
    required bool onlyRemaining,
    DateTime? loggedAt,
  }) async {
    final watched = ref.read(watchedEpisodesMapProvider(tmdbId));
    final episodes = ref
        .read(seriesDomainServiceProvider)
        .airedEpisodes(series)
        .where(
          (e) =>
              !onlyRemaining || (watched['${e.season}-${e.episode}'] ?? 0) == 0,
        )
        .toList();
    if (episodes.isEmpty) return;
    await logMultipleEpisodes(
      tmdbId: tmdbId,
      episodes: episodes,
      loggedAt: loggedAt,
    );
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

  /// Hides an episode's latest watch at once and removes it unless
  /// [undone] completes with true (see [TitleRemovals.removeUnlessUndone]).
  Future<void> deleteLatestEpisodeLog({
    required int tmdbId,
    required int season,
    required int episode,
    required Future<bool> undone,
  }) => _removeEpisodeLogs(tmdbId, season, episode, undone, onlyLatest: true);

  /// Hides every watch of an episode at once and removes them unless
  /// [undone] completes with true (see [TitleRemovals.removeUnlessUndone]).
  Future<void> deleteAllEpisodeLogs({
    required int tmdbId,
    required int season,
    required int episode,
    required Future<bool> undone,
  }) => _removeEpisodeLogs(tmdbId, season, episode, undone, onlyLatest: false);

  Future<void> _removeEpisodeLogs(
    int tmdbId,
    int season,
    int episode,
    Future<bool> undone, {
    required bool onlyLatest,
  }) async {
    final userId = _userId;
    if (userId == null) return;

    // Read again after each wait: the page may have closed meanwhile.
    OptimisticSeriesLogs logs() =>
        ref.read(seriesWatchLogsProvider(tmdbId).notifier);
    final hidden = logs().changeEpisodeCount(
      season,
      episode,
      (shown) => onlyLatest ? shown - 1 : 0,
    );
    await _removals.removeUnlessUndone(
      title: 'tv-$tmdbId',
      undone: undone,
      remove: () => onlyLatest
          ? _repository.deleteLatestEpisodeLog(
              userId: userId,
              tmdbId: tmdbId,
              season: season,
              episode: episode,
            )
          : _repository.deleteAllEpisodeLogs(
              userId: userId,
              tmdbId: tmdbId,
              season: season,
              episode: episode,
            ),
      // Adds back only the watches this removal hid: one marked meanwhile
      // keeps showing.
      showAgain: () =>
          logs().changeEpisodeCount(season, episode, (shown) => shown + hidden),
      action: onlyLatest ? 'deleteLatestEpisodeLog' : 'deleteAllEpisodeLogs',
    );
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
      await _removals.after('tv-$tmdbId');
      await _repository.logMultipleEpisodes(
        userId: userId,
        tmdbId: tmdbId,
        episodes: episodes,
        series: await _loadSeriesDetails(tmdbId),
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
  Future<MediaItem?> _loadSeriesDetails(int tmdbId) async {
    final series = await ref.read(
      mediaDetailsProvider((id: '$tmdbId', type: 'tv')).future,
    );
    if (series == null) {
      // Safe to go on: the episodes still get logged, Continue Watching just
      // stays on the highest marked one instead of the next.
      AppLogger.warn(
        'MediaDetailsController',
        'Could not load series $tmdbId to find the next episode',
      );
    }
    return series;
  }

  /// Hides every watch of a series at once and removes them unless
  /// [undone] completes with true. On undo they come back; on failure too,
  /// and the error is rethrown for the UI to show.
  Future<void> deleteAllSeriesLogs({
    required int tmdbId,
    required Future<bool> undone,
  }) async {
    final userId = _userId;
    if (userId == null) return;

    ref.read(seriesWatchLogsProvider(tmdbId).notifier).hideAllLogs();
    await _removals.removeUnlessUndone(
      title: 'tv-$tmdbId',
      undone: undone,
      remove: () =>
          _repository.deleteAllSeriesLogs(userId: userId, tmdbId: tmdbId),
      // Read again: the page may have closed meanwhile.
      showAgain: () =>
          ref.read(seriesWatchLogsProvider(tmdbId).notifier).showAllLogs(),
      action: 'deleteAllSeriesLogs',
    );
  }

  Future<void> logMovieWatch({required int tmdbId, DateTime? loggedAt}) async {
    final userId = _userId;
    if (userId == null) return;

    // The app's own "now" (not the server's) so the optimistic log matches the
    // saved one.
    final now = loggedAt ?? DateTime.now();

    ref.read(movieWatchLogsProvider(tmdbId).notifier).addOptimisticLog(now);

    try {
      await _removals.after('movie-$tmdbId');
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

  /// Hides a movie's latest watch at once and removes it unless [undone]
  /// completes with true (see [TitleRemovals.removeUnlessUndone]).
  Future<void> deleteLatestMovieLog({
    required int tmdbId,
    required Future<bool> undone,
  }) => _removeMovieLogs(tmdbId, undone, onlyLatest: true);

  /// Hides every watch of a movie at once and removes them unless [undone]
  /// completes with true (see [TitleRemovals.removeUnlessUndone]).
  Future<void> deleteAllMovieLogs({
    required int tmdbId,
    required Future<bool> undone,
  }) => _removeMovieLogs(tmdbId, undone, onlyLatest: false);

  Future<void> _removeMovieLogs(
    int tmdbId,
    Future<bool> undone, {
    required bool onlyLatest,
  }) async {
    final userId = _userId;
    if (userId == null) return;

    // Read again after each wait: the page may have closed meanwhile.
    OptimisticMovieLogs logs() =>
        ref.read(movieWatchLogsProvider(tmdbId).notifier);
    final hidden = onlyLatest
        ? logs().removeOptimisticLog()
        : logs().optimisticClearAll();
    await _removals.removeUnlessUndone(
      title: 'movie-$tmdbId',
      undone: undone,
      remove: () => onlyLatest
          ? _repository.deleteLatestMovieLog(userId: userId, tmdbId: tmdbId)
          : _repository.deleteAllMovieLogs(userId: userId, tmdbId: tmdbId),
      showAgain: () => logs().showLogsAgain(hidden),
      action: onlyLatest ? 'deleteLatestMovieLog' : 'deleteAllMovieLogs',
    );
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

// Kept alive: nothing watches it and its actions use `ref` after awaiting
// the server, which an autoDispose notifier can't (it's gone by then). Its
// only state is the removals waiting for their Undo.
final mediaDetailsControllerProvider =
    NotifierProvider<MediaDetailsController, void>(MediaDetailsController.new);
