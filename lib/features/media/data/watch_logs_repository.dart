import 'dart:async';

import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/error/supabase_failure.dart';
import 'package:cinemuse_app/core/network/reconnecting_stream.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/core/utils/stream_debounce.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/data/watch_log_events.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/data/watch_history_rows.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/series_domain_service.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final watchLogsRepositoryProvider = Provider<WatchLogsRepository>((ref) {
  return WatchLogsRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(mediaRepositoryProvider),
    ref.watch(appDatabaseProvider),
    ref.watch(watchHistoryRepositoryProvider),
    // Stateless domain logic: built here, so data/ doesn't import
    // application/ (REV-186).
    SeriesDomainService(),
    events: ref.watch(watchLogEventsProvider),
  );
});

/// The watch logs (one row per watch of a movie or episode): logging,
/// undoing and reading them. Each write is one RPC that also fixes the
/// title's history row, then copies that row into the local cache.
class WatchLogsRepository {
  static const _logTag = 'WatchLogsRepository';

  final SupabaseClient _client;
  final MediaRepository _mediaRepo;
  final AppDatabase _db;
  final WatchHistoryRepository _historyRepo;
  final SeriesDomainService _seriesService;

  /// Fired after each log write here and in `WatchProgressRepository`.
  final WatchLogEvents events;

  WatchLogsRepository(
    this._client,
    this._mediaRepo,
    this._db,
    this._historyRepo,
    this._seriesService, {
    WatchLogEvents? events,
  }) : events = events ?? WatchLogEvents();

  /// Live watch logs of one title, newest first, reconnecting after a drop.
  /// Debounced (a batch of logs = one update); cancelling closes the channel.
  Stream<List<Map<String, dynamic>>> watchTitleLogs(
    String userId,
    int tmdbId,
    String mediaType,
  ) {
    return reconnectingStream(
          () => _client
              .from('watch_logs')
              .stream(primaryKey: ['id'])
              .eq('tmdb_id', tmdbId)
              .order('logged_at', ascending: false),
          logTag: _logTag,
        )
        .withAppFailure()
        .debounce(const Duration(milliseconds: 300))
        .map(
          (list) => [
            for (final item in list)
              if (item['user_id'] == userId && item['media_type'] == mediaType)
                item,
          ],
        );
  }

  /// Every watch log of the user with its media details: the timeline.
  Future<List<WatchHistory>> getAllWatchLogs(String userId) async {
    try {
      final logs = await _fetchWatchLogs(userId);
      if (logs.isEmpty) return [];
      final mediaMap = await _resolveUniqueMediaItems(logs);
      final statusMap = await _resolveStatusMap(userId);
      return logs
          .map((log) => _mapLogToWatchHistory(log, userId, mediaMap, statusMap))
          .toList();
    } catch (e, stack) {
      AppLogger.warn(
        _logTag,
        'Failed to fetch all watch logs, falling back to local history',
        error: e,
        stackTrace: stack,
      );
      return _historyRepo.getLocalHistory(userId);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchWatchLogs(String userId) async {
    const pageSize = 1000;
    const parallelBatchSize = 4;

    final allLogs = [...await _fetchLogsPage(userId, 0, pageSize)];
    if (allLogs.length < pageSize) return allLogs;

    for (var offset = pageSize; ; offset += parallelBatchSize * pageSize) {
      final pages = await Future.wait([
        for (var i = 0; i < parallelBatchSize; i++)
          _fetchLogsPage(userId, offset + i * pageSize, pageSize),
      ]);
      for (final page in pages) {
        allLogs.addAll(page);
        if (page.length < pageSize) return allLogs;
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchLogsPage(
    String userId,
    int offset,
    int limit,
  ) async {
    final response = await _client
        .from('watch_logs')
        .select(
          'tmdb_id, media_type, season, episode, logged_at, duration_watched_seconds',
        )
        .eq('user_id', userId)
        .order('logged_at', ascending: false)
        // REV-185: a season logged at once shares one logged_at.
        .order('id')
        .range(offset, offset + limit - 1)
        .withAppFailure();

    return (response as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, MediaItem?>> _resolveUniqueMediaItems(
    List<Map<String, dynamic>> logs,
  ) async {
    final uniqueRequests = <String, ({int id, MediaKind type})>{};
    for (final log in logs) {
      final tmdbId = log['tmdb_id'] as int? ?? 0;
      final typeStr = log['media_type'] as String? ?? 'movie';
      final request = (id: tmdbId, type: MediaItem.fromString(typeStr));
      uniqueRequests.putIfAbsent('$typeStr-$tmdbId', () => request);
    }

    final cached = await _mediaRepo.getMediaItems([...uniqueRequests.values]);
    final mediaMap = <String, MediaItem?>{
      for (final item in cached) '${item.mediaType.name}-${item.tmdbId}': item,
    };

    final missingRequests = uniqueRequests.entries
        .where((entry) => !mediaMap.containsKey(entry.key))
        .toList();

    if (missingRequests.isNotEmpty) {
      await Future.wait(
        missingRequests.map((entry) async {
          final e = entry.value;
          mediaMap[entry.key] = await _mediaRepo.getMediaItem(e.id, e.type);
        }),
      );
    }
    return mediaMap;
  }

  Future<Map<String, WatchStatus>> _resolveStatusMap(String userId) async {
    final statusMap = <String, WatchStatus>{};
    // 1. Check local Drift database (fastest, keeps offline state)
    try {
      final localHistories = await _db.getWatchHistory(userId);
      for (final local in localHistories) {
        statusMap['${local.mediaType}-${local.tmdbId}'] = WatchStatus.fromJson(
          local.status,
        );
      }
    } catch (e, s) {
      // Safe to go on: the server's statuses are read below instead.
      AppLogger.warn(
        _logTag,
        'Failed to read watch status from Drift database for user: $userId',
        error: e,
        stackTrace: s,
      );
    }

    if (statusMap.isEmpty) {
      try {
        final remoteHistory = await _client
            .from('watch_history')
            .select('tmdb_id, media_type, status')
            .eq('user_id', userId)
            .withAppFailure();

        for (final row in remoteHistory) {
          final tmdbId = row['tmdb_id'] as int? ?? 0;
          final typeStr = row['media_type'] as String? ?? 'movie';
          final statusStr = row['status'] as String? ?? 'completed';
          statusMap['$typeStr-$tmdbId'] = WatchStatus.fromJson(statusStr);
        }
      } catch (e, s) {
        // Safe to go on: the logs then show as "completed".
        AppLogger.warn(
          _logTag,
          'Failed to fetch remote watch status from Supabase for user: '
          '$userId',
          error: e,
          stackTrace: s,
        );
      }
    }

    return statusMap;
  }

  WatchHistory _mapLogToWatchHistory(
    Map<String, dynamic> log,
    String userId,
    Map<String, MediaItem?> mediaMap,
    Map<String, WatchStatus> statusMap,
  ) {
    final tmdbId = log['tmdb_id'] as int? ?? 0;
    final typeStr = log['media_type'] as String? ?? 'movie';
    final kind = MediaItem.fromString(typeStr);
    final loggedAtStr = log['logged_at'] as String?;
    final loggedAt = loggedAtStr != null
        ? DateTime.parse(loggedAtStr)
        : DateTime.now();

    final status = statusMap['$typeStr-$tmdbId'] ?? WatchStatus.completed;

    return WatchHistory(
      userId: userId,
      tmdbId: tmdbId,
      mediaType: kind,
      status: status,
      progressSeconds: log['duration_watched_seconds'] as int? ?? 0,
      lastWatchedAt: loggedAt,
      season: log['season'] as int?,
      episode: log['episode'] as int?,
      media: mediaMap['$typeStr-$tmdbId'],
    );
  }

  /// The show's highest logged regular episode, or null when none is logged
  /// (specials are extras, REV-264). Throws an [AppFailure].
  Future<({int season, int episode})?> getHighestLoggedEpisode(
    String userId,
    int tmdbId,
  ) async {
    final row = await _client
        .from('watch_logs')
        .select('season, episode')
        .eq('user_id', userId)
        .eq('tmdb_id', tmdbId)
        .eq('media_type', 'tv')
        .order('season', ascending: false)
        .order('episode', ascending: false)
        .limit(1)
        .maybeSingle()
        .withAppFailure();
    if (row == null || (row['season'] as int? ?? 0) <= 0) return null;
    return (
      season: row['season'] as int? ?? 0,
      episode: row['episode'] as int? ?? 0,
    );
  }

  /// Logs a watch of a movie at [loggedAt] and, if it's the movie's newest
  /// watch, sets it to "completed", in one `log_movie_watch` RPC (one
  /// transaction). [isNow] = no date was picked: the server then counts it as
  /// newest even if the row's time is later. Throws an [AppFailure].
  Future<void> logMovieWatch({
    required String userId,
    required int tmdbId,
    required DateTime loggedAt,
    required bool isNow,
  }) async {
    final rows = await _client
        .rpc(
          'log_movie_watch',
          params: {
            'p_tmdb_id': tmdbId,
            // REV-178: UTC, so the server compares it with the right time.
            'p_logged_at': loggedAt.toUtc().toIso8601String(),
            'p_is_now': isNow,
          },
        )
        .withAppFailure();
    await cacheReturnedRow(_db, userId, tmdbId, 'movie', rows);
    events.notifyWritten();
  }

  /// Marks [episodes] of a show as watched at [loggedAt] (null = now) and,
  /// unless an older date was picked, moves Continue Watching on (see
  /// [SeriesDomainService.episodeToContinueFrom]), in one `log_episodes` RPC
  /// (one transaction). Without the [series]' details the next episode is
  /// unknown, so the show stays at the highest marked episode. Throws an
  /// [AppFailure].
  Future<void> logMultipleEpisodes({
    required String userId,
    required int tmdbId,
    required List<({int season, int episode})> episodes,
    MediaItem? series,
    DateTime? loggedAt,
  }) async {
    if (episodes.isEmpty) return;

    // Choosing the next episode needs TMDB data, so it's done here.
    final from = SeriesDomainService.episodeToContinueFrom(
      episodes,
      highestRegular: episodes.every((e) => e.season == 0)
          ? await getHighestLoggedEpisode(userId, tmdbId)
          : null,
    );
    final next = series == null
        ? null
        : _seriesService.getNextEpisode(series, from.season, from.episode);

    final rows = await _client
        .rpc(
          'log_episodes',
          params: {
            'p_tmdb_id': tmdbId,
            'p_episodes': [
              for (final e in episodes)
                {'season': e.season, 'episode': e.episode},
            ],
            // REV-178: UTC, so the server compares it with the right time.
            'p_logged_at': loggedAt?.toUtc().toIso8601String(),
            'p_next_season': next?.next?.season,
            'p_next_episode': next?.next?.episode,
            'p_next_aired': next?.isAired ?? false,
          },
        )
        .withAppFailure();
    await cacheReturnedRow(_db, userId, tmdbId, 'tv', rows);
    events.notifyWritten();
  }

  /// Removes the newest watch of a movie. Throws an [AppFailure].
  Future<void> deleteLatestMovieLog({
    required String userId,
    required int tmdbId,
  }) => _undoWatch(
    userId: userId,
    tmdbId: tmdbId,
    mediaType: 'movie',
    onlyLatest: true,
  );

  /// Removes every watch of a movie. Throws an [AppFailure].
  Future<void> deleteAllMovieLogs({
    required String userId,
    required int tmdbId,
  }) => _undoWatch(
    userId: userId,
    tmdbId: tmdbId,
    mediaType: 'movie',
    onlyLatest: false,
  );

  /// Removes the newest watch of an episode. Throws an [AppFailure].
  Future<void> deleteLatestEpisodeLog({
    required String userId,
    required int tmdbId,
    required int season,
    required int episode,
  }) => _undoWatch(
    userId: userId,
    tmdbId: tmdbId,
    mediaType: 'tv',
    season: season,
    episode: episode,
    onlyLatest: true,
  );

  /// Removes every watch of an episode. Throws an [AppFailure].
  Future<void> deleteAllEpisodeLogs({
    required String userId,
    required int tmdbId,
    required int season,
    required int episode,
  }) => _undoWatch(
    userId: userId,
    tmdbId: tmdbId,
    mediaType: 'tv',
    season: season,
    episode: episode,
    onlyLatest: false,
  );

  /// Removes every watch of a series. Throws an [AppFailure].
  Future<void> deleteAllSeriesLogs({
    required String userId,
    required int tmdbId,
  }) => _undoWatch(
    userId: userId,
    tmdbId: tmdbId,
    mediaType: 'tv',
    onlyLatest: false,
  );

  /// Calls the `undo_watch` RPC, which removes the logs and fixes the title's
  /// row in one transaction, then copies that row into the local cache.
  /// [season] / [episode] null = every log of the title. Throws an
  /// [AppFailure].
  Future<void> _undoWatch({
    required String userId,
    required int tmdbId,
    required String mediaType,
    int? season,
    int? episode,
    required bool onlyLatest,
  }) async {
    final rows = await _client
        .rpc(
          'undo_watch',
          params: {
            'p_tmdb_id': tmdbId,
            'p_media_type': mediaType,
            'p_season': season,
            'p_episode': episode,
            'p_only_latest': onlyLatest,
          },
        )
        .withAppFailure();
    await cacheReturnedRow(_db, userId, tmdbId, mediaType, rows);
    events.notifyWritten();
  }
}
