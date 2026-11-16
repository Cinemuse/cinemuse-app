import 'package:cinemuse_app/core/constants/playback_constants.dart';
import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/error/supabase_failure.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_rows.dart';
import 'package:cinemuse_app/features/media/data/watch_logs_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/media/domain/series_domain_service.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final watchProgressRepositoryProvider = Provider<WatchProgressRepository>((
  ref,
) {
  return WatchProgressRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(appDatabaseProvider),
    ref.watch(watchLogsRepositoryProvider),
    ref.watch(tmdbServiceProvider),
    // Stateless domain logic: built here, so data/ doesn't import
    // application/ (REV-186).
    SeriesDomainService(),
  );
});

/// Where the user is in a title (Continue Watching): playback progress,
/// finishing an episode, Drop / Restore, clearing progress, ending a
/// rewatch. Server first, then the local cache.
class WatchProgressRepository {
  static const _logTag = 'WatchProgressRepository';

  final SupabaseClient _client;
  final AppDatabase _db;
  final WatchLogsRepository _logsRepo;
  final TmdbService _tmdbService;
  final SeriesDomainService _seriesService;

  WatchProgressRepository(
    this._client,
    this._db,
    this._logsRepo,
    this._tmdbService,
    this._seriesService,
  );

  /// Saves the playback position, server first, then the local cache.
  /// Near the end it finishes the title instead (log + move on, see
  /// [_completeWatch]); too little watched saves nothing. Throws an
  /// [AppFailure].
  Future<void> updateProgress({
    required String userId,
    required MediaItem media,
    required int progressSeconds,
    required int totalDuration,
    int? season,
    int? episode,
    MediaItem? series,
    int actualSecondsWatched = 0,
    int? initialPosition,
  }) async {
    if (totalDuration <= 0) return;

    final progressPercentage = progressSeconds / totalDuration;
    final remainingSeconds = totalDuration - progressSeconds;

    if (remainingSeconds < PlaybackThresholds.completionRemainingSeconds ||
        progressPercentage > PlaybackThresholds.completionPercentage) {
      // Choosing the next episode needs TMDB data, so it's done here.
      final next =
          media.mediaType == MediaKind.tv &&
              season != null &&
              episode != null &&
              series != null
          ? await _episodeAfter(userId, media.tmdbId, series, season, episode)
          : null;

      // The player keeps saving after the end: only the first save, while
      // the episode is still "watching", may log it and move on.
      await _completeWatch(
        userId: userId,
        tmdbId: media.tmdbId,
        mediaType: media.mediaType.name,
        season: season ?? 0,
        episode: episode ?? 0,
        durationWatched: progressSeconds,
        next: next,
        onlyIfWatching: true,
      );
      return;
    }

    // Peeking: too little watched to save.
    if (progressSeconds < PlaybackThresholds.peekingSeconds &&
        progressPercentage < PlaybackThresholds.peekingPercentage) {
      return;
    }

    // 3. Watching State (Implicitly: Progress > 120s OR Progress > 10%)
    final now = DateTime.now().toUtc(); // REV-178: the server stores UTC.
    final entry = {
      'user_id': userId,
      'tmdb_id': media.tmdbId,
      'media_type': media.mediaType.name,
      'status': 'watching',
      'progress_seconds': progressSeconds,
      'total_duration': totalDuration,
      'season': season ?? 0,
      'episode': episode ?? 0,
      'last_watched_at': now.toIso8601String(),
    };

    // Server first: offline nothing is saved, not even locally, or the
    // next sync would silently undo it (DATA-03). Both get the same row.
    await _client.from('watch_history').upsert(entry).withAppFailure();
    await _db.upsertWatchHistory(localEntryFromRemote(userId, entry));
  }

  /// Explicitly marks an episode as completed, regardless of playback position.
  /// Used when the user presses "Next Episode" and has watched enough (≥ skip threshold).
  ///
  /// Logs the episode and moves Continue Watching to the next one in a single
  /// `complete_watch` RPC (one transaction), so a dropped connection can't
  /// leave it half done. Throws an [AppFailure].
  Future<void> completeEpisode({
    required String userId,
    required int tmdbId,
    required int season,
    required int episode,
    int? durationWatched,
    MediaItem? series,
  }) async {
    // Choosing the next episode needs TMDB data, so it's done here.
    final next = series == null
        ? null
        : await _episodeAfter(userId, tmdbId, series, season, episode);

    await _completeWatch(
      userId: userId,
      tmdbId: tmdbId,
      mediaType: 'tv',
      season: season,
      episode: episode,
      durationWatched: durationWatched,
      next: next,
      onlyIfWatching: false,
    );
    // Always a new log, even when the title's row doesn't change (an
    // episode already completed). The player's own finish (updateProgress)
    // isn't announced: its first save changes the row, which the history
    // stream already shows, and the saves after the end log nothing
    // (PERF-02).
    _logsRepo.events.notifyWritten();
  }

  /// Where Continue Watching moves after [season] / [episode] is finished.
  /// After a special it goes back to the regular episodes: the one after the
  /// highest regular episode logged (REV-264). Throws an [AppFailure].
  Future<({NextEpisodeInfo? next, bool isAired})> _episodeAfter(
    String userId,
    int tmdbId,
    MediaItem series,
    int season,
    int episode,
  ) async {
    final from = SeriesDomainService.episodeToContinueFrom(
      [(season: season, episode: episode)],
      highestRegular: season == 0
          ? await _logsRepo.getHighestLoggedEpisode(userId, tmdbId)
          : null,
    );
    return _seriesService.getNextEpisode(series, from.season, from.episode);
  }

  /// Calls the `complete_watch` RPC (remove from Continue Watching, log, move
  /// on to [next]) and copies the title's returned row into the local cache.
  /// With [onlyIfWatching], the server does nothing unless the episode was
  /// still "watching". Throws an [AppFailure].
  Future<void> _completeWatch({
    required String userId,
    required int tmdbId,
    required String mediaType,
    required int season,
    required int episode,
    required int? durationWatched,
    required ({NextEpisodeInfo? next, bool isAired})? next,
    required bool onlyIfWatching,
  }) async {
    final rows = await _client
        .rpc(
          'complete_watch',
          params: {
            'p_tmdb_id': tmdbId,
            'p_media_type': mediaType,
            'p_season': season,
            'p_episode': episode,
            'p_duration_watched': durationWatched,
            'p_next_season': next?.next?.season,
            'p_next_episode': next?.next?.episode,
            'p_next_aired': next?.isAired ?? false,
            'p_only_if_watching': onlyIfWatching,
          },
        )
        .withAppFailure();
    await cacheReturnedRow(_db, userId, tmdbId, mediaType, rows);
  }

  /// Moves the title to Dropped. Throws an [AppFailure].
  Future<void> dropFromContinueWatching(
    String userId,
    int tmdbId,
    String mediaType,
  ) => _setStatus(userId, tmdbId, mediaType, 'dropped');

  /// Puts a dropped title back in Continue Watching. Throws an [AppFailure].
  Future<void> restoreToContinueWatching(
    String userId,
    int tmdbId,
    String mediaType,
  ) => _setStatus(userId, tmdbId, mediaType, 'watching');

  /// Sets one title's status, server first: if it fails, the local copy
  /// stays as it was (REV-106).
  Future<void> _setStatus(
    String userId,
    int tmdbId,
    String mediaType,
    String status,
  ) async {
    await whereTitleRow(
      _client.from('watch_history').update({'status': status}),
      userId,
      tmdbId,
      mediaType,
    ).withAppFailure();
    await (_db.update(_db.localWatchHistories)..where(
          (t) =>
              t.userId.equals(userId) &
              t.tmdbId.equals(tmdbId) &
              t.mediaType.equals(mediaType),
        ))
        .write(LocalWatchHistoriesCompanion(status: Value(status)));
  }

  /// Clears a title's progress ("Remove from Continue Watching") in one
  /// `clear_progress` RPC: a title never logged loses its row, a movie seen
  /// before becomes "completed" again, a show keeps its current episode with
  /// progress 0. Throws an [AppFailure].
  Future<void> clearProgress({
    required String userId,
    required int tmdbId,
    required String mediaType,
  }) async {
    final rows = await _client
        .rpc(
          'clear_progress',
          params: {'p_tmdb_id': tmdbId, 'p_media_type': mediaType},
        )
        .withAppFailure();
    await cacheReturnedRow(_db, userId, tmdbId, mediaType, rows);
  }

  /// Stops a rewatch: the title goes back to where the user was before it
  /// (a movie or a finished show becomes "completed", otherwise the episode
  /// after the highest one logged becomes "watching"), in one
  /// `cancel_rewatch` RPC. A show needs its [end] from [rewatchEnd]. Throws
  /// an [AppFailure].
  Future<void> cancelRewatch(
    String userId,
    int tmdbId,
    String mediaType, {
    required RewatchEnd? end,
  }) async {
    final next = end == null || end.finished ? null : end;
    final rows = await _client
        .rpc(
          'cancel_rewatch',
          params: {
            'p_tmdb_id': tmdbId,
            'p_media_type': mediaType,
            'p_next_season': next?.season,
            'p_next_episode': next?.episode,
            'p_next_aired': next != null,
          },
        )
        .withAppFailure();
    await cacheReturnedRow(_db, userId, tmdbId, mediaType, rows);
  }

  /// Where "Stop rewatching" takes a show (choosing it needs TMDB data).
  /// Null when nothing is logged. Throws an [AppFailure].
  Future<RewatchEnd?> rewatchEnd(String userId, int tmdbId) async {
    final highest = await _logsRepo.getHighestLoggedEpisode(userId, tmdbId);
    if (highest == null) return null;
    final atHighest = (
      season: highest.season,
      episode: highest.episode,
      finished: true,
    );

    final MediaItem? series;
    try {
      series = await _tmdbService.getMediaDetails(tmdbId.toString(), 'tv');
    } catch (e, st) {
      // Safe to go on: without a next episode the server marks the highest
      // logged one as completed, which is still a valid state.
      AppLogger.warn(
        _logTag,
        'TMDB details for show $tmdbId failed; cancelling the rewatch '
        'without a next episode',
        error: e,
        stackTrace: st,
      );
      return atHighest;
    }
    if (series == null) return atHighest;

    final (:next, :isAired) = _seriesService.getNextEpisode(
      series,
      highest.season,
      highest.episode,
    );
    if (next == null || !isAired) return atHighest;
    return (season: next.season, episode: next.episode, finished: false);
  }
}
