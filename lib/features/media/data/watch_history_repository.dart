import 'dart:async';
import 'dart:developer' as developer;
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/error/supabase_extensions.dart';
import 'package:cinemuse_app/core/error/supabase_failure.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:drift/drift.dart';
import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/core/constants/playback_constants.dart';
import 'package:cinemuse_app/features/media/application/series_domain_service.dart';

import 'package:cinemuse_app/features/media/data/tmdb_service.dart';

final watchHistoryRepositoryProvider = Provider<WatchHistoryRepository>((ref) {
  return WatchHistoryRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(mediaRepositoryProvider),
    ref.watch(appDatabaseProvider),
    ref.watch(seriesDomainServiceProvider),
    ref.watch(tmdbServiceProvider),
  );
});

class WatchHistoryRepository {
  final SupabaseClient _client;
  final MediaRepository _mediaRepo;
  final AppDatabase _db;
  final SeriesDomainService _seriesService;
  final TmdbService _tmdbService;

  /// In-memory cache for timeline watch logs to avoid redundant network & database roundtrips
  List<WatchHistory>? _cachedWatchLogs;

  void invalidateWatchLogsCache() {
    _cachedWatchLogs = null;
  }

  WatchHistoryRepository(
    this._client,
    this._mediaRepo,
    this._db,
    this._seriesService,
    this._tmdbService,
  );

  // Get current "Continue Watching" list (status = watching)
  Future<List<WatchHistory>> getContinueWatching(String userId) async {
    final response = await _client
        .from('watch_history')
        .select() // Join with media_cache removed
        .eq('user_id', userId)
        .eq('status', 'watching')
        .order('last_watched_at', ascending: false)
        .withErrorHandling();

    return (response as List).map((e) => WatchHistory.fromJson(e)).toList();
  }

  // Get dropped items
  Future<List<WatchHistory>> getDroppedItems(String userId) async {
    final response = await _client
        .from('watch_history')
        .select()
        .eq('user_id', userId)
        .eq('status', 'dropped')
        .order('last_watched_at', ascending: false)
        .withErrorHandling();

    return (response as List).map((e) => WatchHistory.fromJson(e)).toList();
  }

  /// Ensures a media item exists in the local cache.
  Future<void> saveMediaItem(MediaItem media) async {
    await _mediaRepo.saveMediaItem(media);
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
    Map<String, dynamic>? seriesDetails,
  }) async {
    // Choosing the next episode needs TMDB data, so it's done here.
    final next = seriesDetails == null
        ? null
        : _seriesService.getNextEpisode(seriesDetails, season, episode);

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
    invalidateWatchLogsCache();
    await _cacheReturnedRow(userId, tmdbId, mediaType, rows);
  }

  /// Copies the title's row returned by an RPC into the local cache
  /// (no row = the title has none left).
  Future<void> _cacheReturnedRow(
    String userId,
    int tmdbId,
    String mediaType,
    dynamic rows,
  ) async {
    final row = (rows as List).firstOrNull as Map<String, dynamic>?;
    if (row == null) {
      await _db.deleteWatchHistoryItem(userId, tmdbId, mediaType);
    } else {
      await _db.upsertWatchHistory(_localEntryFromRemote(userId, row));
    }
  }

  Future<void> updateProgress({
    required String userId,
    required MediaItem media,
    required int progressSeconds,
    required int totalDuration,
    int? season,
    int? episode,
    Map<String, dynamic>? seriesDetails,
    int actualSecondsWatched = 0,
    int? initialPosition,
  }) async {
    if (totalDuration <= 0) return;

    final progressPercentage = progressSeconds / totalDuration;
    final remainingSeconds = totalDuration - progressSeconds;

    // 1. Check for Completed State
    // Remaining < 180s OR Progress > 95%
    if (remainingSeconds < PlaybackThresholds.completionRemainingSeconds ||
        progressPercentage > PlaybackThresholds.completionPercentage) {
      // Choosing the next episode needs TMDB data, so it's done here.
      final next =
          media.mediaType == MediaKind.tv &&
              season != null &&
              episode != null &&
              seriesDetails != null
          ? _seriesService.getNextEpisode(seriesDetails, season, episode)
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

    // 2. Check for Peeking State
    // Watched < 120s AND Watched < 10%
    if (progressSeconds < PlaybackThresholds.peekingSeconds &&
        progressPercentage < PlaybackThresholds.peekingPercentage) {
      // Do nothing, don't save to history
      return;
    }

    // 3. Watching State (Implicitly: Progress > 120s OR Progress > 10%)

    final entry = {
      'user_id': userId,
      'tmdb_id': media.tmdbId,
      'media_type': media.mediaType.name,
      'status': 'watching',
      'progress_seconds': progressSeconds,
      'total_duration': totalDuration,
      'season': season ?? 0,
      'episode': episode ?? 0,
      'last_watched_at': DateTime.now().toIso8601String(),
    };

    // Update Local Cache
    await _db.upsertWatchHistory(
      LocalWatchHistoriesCompanion(
        userId: Value(userId),
        tmdbId: Value(media.tmdbId),
        mediaType: Value(media.mediaType.name),
        status: Value('watching'),
        progressSeconds: Value(progressSeconds),
        totalDuration: Value(totalDuration),
        season: Value(season ?? 0),
        episode: Value(episode ?? 0),
        lastWatchedAt: Value(DateTime.now()),
      ),
    );

    // Update Remote
    await _client.from('watch_history').upsert(entry).withErrorHandling();
  }

  Future<WatchHistory?> getHistoryItem(String userId, String tmdbId) async {
    if (int.tryParse(tmdbId) == null) {
      return null;
    }
    final response = await _client
        .from('watch_history')
        .select()
        .eq('user_id', userId)
        .eq('tmdb_id', tmdbId)
        .eq('status', 'watching')
        .order('last_watched_at', ascending: false)
        .limit(1)
        .maybeSingle()
        .withErrorHandling();

    if (response == null) return null;
    return WatchHistory.fromJson(response);
  }

  Stream<List<WatchHistory>> watchHistory(String userId) {
    return _db.watchWatchHistory(userId).asyncMap((list) async {
      final futures = list.map((local) async {
        final mediaType = MediaItem.fromString(local.mediaType);
        final mediaKind = MediaKind.values.firstWhere(
          (e) => e.name == local.mediaType,
          orElse: () => MediaKind.movie,
        );

        // Try to get media metadata (now handles TMDB fallback)
        final media = await _mediaRepo.getMediaItem(local.tmdbId, mediaKind);

        return WatchHistory(
          userId: local.userId,
          tmdbId: local.tmdbId,
          mediaType: mediaType,
          status: WatchStatus.fromJson(local.status),
          progressSeconds: local.progressSeconds,
          totalDuration: local.totalDuration,
          watchCount: 0,
          lastWatchedAt: local.lastWatchedAt,
          season: local.season,
          episode: local.episode,
          media: media,
        );
      });

      return Future.wait(futures);
    });
  }

  /// Syncs watch history from Supabase to Drift.
  /// Should be called on app startup or periodically.
  Future<void> syncWatchHistory(String userId) async {
    try {
      final allRemoteData = <dynamic>[];
      int offset = 0;
      const limit = 1000;
      bool hasMore = true;

      while (hasMore) {
        final remoteData = await _client
            .from('watch_history')
            .select()
            .eq('user_id', userId)
            .range(offset, offset + limit - 1)
            .withErrorHandling();

        final dataList = remoteData as List<dynamic>;
        allRemoteData.addAll(dataList);

        if (dataList.length < limit) {
          hasMore = false;
        } else {
          offset += limit;
        }
      }

      final companions = allRemoteData
          .map((json) => _localEntryFromRemote(userId, json))
          .toList();

      await _db.syncWatchHistory(userId, companions);
    } catch (e, s) {
      developer.log(
        'Failed to sync remote watch history to Drift database for user: $userId',
        name: 'WatchHistoryRepository',
        error: e,
        stackTrace: s,
      );
    }
  }

  /// A `watch_history` row from Supabase as a local Drift entry.
  LocalWatchHistoriesCompanion _localEntryFromRemote(
    String userId,
    Map<String, dynamic> json,
  ) {
    final lastWatched = json['last_watched_at'] != null
        ? DateTime.parse(json['last_watched_at'])
        : DateTime.now();

    return LocalWatchHistoriesCompanion(
      userId: Value(userId),
      tmdbId: Value(json['tmdb_id'] as int? ?? 0),
      mediaType: Value(json['media_type'] as String? ?? 'movie'),
      status: Value(json['status'] as String? ?? 'watching'),
      progressSeconds: Value(json['progress_seconds'] as int? ?? 0),
      totalDuration: Value(json['total_duration'] as int? ?? 0),
      season: Value(json['season'] as int? ?? 0),
      episode: Value(json['episode'] as int? ?? 0),
      lastWatchedAt: Value(lastWatched),
    );
  }

  Stream<List<WatchHistory>> watchAllHistory(String userId) {
    // We now prefer watchHistory(userId) which uses Drift.
    // This is kept for compatibility or specific stream requirement.
    return watchHistory(userId);
  }

  // Stream movie logs for a specific user and tmdbId
  Stream<List<Map<String, dynamic>>> watchMovieLogs(String userId, int tmdbId) {
    return _client
        .from('watch_logs')
        .stream(primaryKey: ['id'])
        .eq('tmdb_id', tmdbId)
        .order('logged_at', ascending: false)
        .withErrorHandling()
        .transform(_debounceTransformer(const Duration(milliseconds: 300)))
        .map(
          (list) => list
              .where(
                (item) =>
                    item['user_id'] == userId && item['media_type'] == 'movie',
              )
              .toList(),
        );
  }

  // Stream series logs for a specific user and tmdbId
  Stream<List<Map<String, dynamic>>> watchSeriesLogs(
    String userId,
    int tmdbId,
  ) {
    return _client
        .from('watch_logs')
        .stream(primaryKey: ['id'])
        .eq('tmdb_id', tmdbId)
        .order('logged_at', ascending: false)
        .withErrorHandling()
        .transform(_debounceTransformer(const Duration(milliseconds: 300)))
        .map(
          (list) => list
              .where(
                (item) =>
                    item['user_id'] == userId && item['media_type'] == 'tv',
              )
              .toList(),
        );
  }

  // Stream watch_history (progress) for a specific series
  Stream<List<WatchHistory>> watchSeriesHistory(String userId, int tmdbId) {
    return watchHistory(
      userId,
    ).map((list) => list.where((e) => e.tmdbId == tmdbId).toList());
  }

  /// Fetches all watch log entries for a user, enriched with media metadata.
  /// Serves as the single source of truth for watch history timeline visualizations.
  Future<List<WatchHistory>> getAllWatchLogs(
    String userId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedWatchLogs != null) {
      return _cachedWatchLogs!;
    }
    try {
      final logs = await _fetchWatchLogs(userId);
      if (logs.isEmpty) {
        _cachedWatchLogs = [];
        return [];
      }

      final mediaMap = await _resolveUniqueMediaItems(logs);
      final statusMap = await _resolveStatusMap(userId);
      final result = logs
          .map((log) => _mapLogToWatchHistory(log, userId, mediaMap, statusMap))
          .toList();
      _cachedWatchLogs = result;
      return result;
    } catch (e, stack) {
      developer.log(
        'Failed to fetch all watch logs, falling back to local history',
        name: 'WatchHistoryRepository',
        error: e,
        stackTrace: stack,
      );
      return _getLocalHistoryFallback(userId);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchWatchLogs(String userId) async {
    const pageSize = 1000;
    const parallelBatchSize = 4;

    final firstPage = await _fetchLogsPage(userId, 0, pageSize);
    if (firstPage.length < pageSize) {
      return firstPage;
    }

    final allLogs = <Map<String, dynamic>>[...firstPage];
    int currentOffset = pageSize;
    bool hasMore = true;

    while (hasMore) {
      final futures = <Future<List<Map<String, dynamic>>>>[];
      for (int i = 0; i < parallelBatchSize; i++) {
        final pageOffset = currentOffset + (i * pageSize);
        futures.add(_fetchLogsPage(userId, pageOffset, pageSize));
      }

      final pages = await Future.wait(futures);
      for (final page in pages) {
        allLogs.addAll(page);
        if (page.length < pageSize) {
          hasMore = false;
          break;
        }
      }
      currentOffset += parallelBatchSize * pageSize;
    }

    return allLogs;
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
        .range(offset, offset + limit - 1)
        .withErrorHandling();

    return (response as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, MediaItem?>> _resolveUniqueMediaItems(
    List<Map<String, dynamic>> logs,
  ) async {
    final uniqueRequests = <String, ({int id, MediaKind type})>{};
    for (final log in logs) {
      final tmdbId = log['tmdb_id'] as int? ?? 0;
      final typeStr = log['media_type'] as String? ?? 'movie';
      final kind = typeStr == 'tv' ? MediaKind.tv : MediaKind.movie;
      uniqueRequests.putIfAbsent(
        '$typeStr-$tmdbId',
        () => (id: tmdbId, type: kind),
      );
    }

    final mediaMap = <String, MediaItem?>{};
    final bulkResults = await _mediaRepo.getMediaItems(
      uniqueRequests.values.toList(),
    );
    for (final item in bulkResults) {
      mediaMap['${item.mediaType.name}-${item.tmdbId}'] = item;
    }

    final missingRequests = uniqueRequests.entries
        .where((entry) => !mediaMap.containsKey(entry.key))
        .toList();

    if (missingRequests.isNotEmpty) {
      await Future.wait(
        missingRequests.map((entry) async {
          final media = await _mediaRepo.getMediaItem(
            entry.value.id,
            entry.value.type,
          );
          mediaMap[entry.key] = media;
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
      developer.log(
        'Failed to read watch status from Drift database for user: $userId',
        name: 'WatchHistoryRepository',
        error: e,
        stackTrace: s,
      );
    }

    // 2. If local database has no status entries, fetch from Supabase watch_history
    if (statusMap.isEmpty) {
      try {
        final remoteHistory = await _client
            .from('watch_history')
            .select('tmdb_id, media_type, status')
            .eq('user_id', userId)
            .withErrorHandling();

        for (final row in remoteHistory) {
          final tmdbId = row['tmdb_id'] as int? ?? 0;
          final typeStr = row['media_type'] as String? ?? 'movie';
          final statusStr = row['status'] as String? ?? 'completed';
          statusMap['$typeStr-$tmdbId'] = WatchStatus.fromJson(statusStr);
        }
      } catch (e, s) {
        developer.log(
          'Failed to fetch remote watch status from Supabase for user: $userId',
          name: 'WatchHistoryRepository',
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
    final kind = typeStr == 'tv' ? MediaKind.tv : MediaKind.movie;
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

  Future<List<WatchHistory>> _getLocalHistoryFallback(String userId) async {
    final list = await _db.getWatchHistory(userId);
    final futures = list.map((local) async {
      final mediaKind = local.mediaType == 'tv'
          ? MediaKind.tv
          : MediaKind.movie;
      final media = await _mediaRepo.getMediaItem(local.tmdbId, mediaKind);
      return WatchHistory(
        userId: local.userId,
        tmdbId: local.tmdbId,
        mediaType: mediaKind,
        status: WatchStatus.fromJson(local.status),
        progressSeconds: local.progressSeconds,
        totalDuration: local.totalDuration,
        lastWatchedAt: local.lastWatchedAt,
        season: local.season,
        episode: local.episode,
        media: media,
      );
    });
    return Future.wait(futures);
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
    invalidateWatchLogsCache();
    await _cacheReturnedRow(userId, tmdbId, 'movie', rows);
  }

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
    invalidateWatchLogsCache();
    await _cacheReturnedRow(userId, tmdbId, mediaType, rows);
  }

  /// Marks [episodes] of a show as watched at [loggedAt] (null = now) and,
  /// unless an older date was picked, moves Continue Watching on to the
  /// episode after the highest one, in one `log_episodes` RPC (one
  /// transaction). Without [seriesDetails] the next episode is unknown, so
  /// the show stays at the highest marked episode. Throws an [AppFailure].
  Future<void> logMultipleEpisodes({
    required String userId,
    required int tmdbId,
    required List<({int season, int episode})> episodes,
    Map<String, dynamic>? seriesDetails,
    DateTime? loggedAt,
  }) async {
    if (episodes.isEmpty) return;

    final latest = episodes.reduce(
      (a, b) =>
          (b.season > a.season ||
              (b.season == a.season && b.episode > a.episode))
          ? b
          : a,
    );
    // Choosing the next episode needs TMDB data, so it's done here.
    final next = seriesDetails == null
        ? null
        : _seriesService.getNextEpisode(
            seriesDetails,
            latest.season,
            latest.episode,
          );

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
    invalidateWatchLogsCache();
    await _cacheReturnedRow(userId, tmdbId, 'tv', rows);
  }

  /// Ensures an episode is marked as watching with 0 progress if not already tracked.
  /// Used for auto-advancing to new seasons.
  Future<void> ensureEpisodeWatching({
    required String userId,
    required int tmdbId,
    required int season,
    required int episode,
  }) async {
    // Check if we already have progress for this episode
    final existing = await _client
        .from('watch_history')
        .select('progress_seconds')
        .eq('user_id', userId)
        .eq('tmdb_id', tmdbId)
        .eq('season', season)
        .eq('episode', episode)
        .maybeSingle();

    if (existing == null) {
      // Update Local
      await _db.upsertWatchHistory(
        LocalWatchHistoriesCompanion(
          userId: Value(userId),
          tmdbId: Value(tmdbId),
          mediaType: Value('tv'),
          season: Value(season),
          episode: Value(episode),
          status: Value('watching'),
          progressSeconds: Value(0),
          totalDuration: Value(0),
          lastWatchedAt: Value(DateTime.now()),
        ),
      );

      // Update Remote
      await _client.from('watch_history').upsert({
        'user_id': userId,
        'tmdb_id': tmdbId,
        'media_type': 'tv',
        'season': season,
        'episode': episode,
        'status': 'watching',
        'progress_seconds': 0,
        'total_duration': 0,
        'last_watched_at': DateTime.now().toIso8601String(),
      });
    }
  }

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

  /// Stops a rewatch: the title goes back to where the user was before it
  /// (a movie or a finished show becomes "completed", otherwise the episode
  /// after the highest one logged becomes "watching"), in one
  /// `cancel_rewatch` RPC. Throws an [AppFailure].
  Future<void> cancelRewatch(
    String userId,
    int tmdbId,
    String mediaType,
  ) async {
    final next = mediaType == 'tv'
        ? await _episodeAfterHighestLog(userId, tmdbId)
        : null;

    final rows = await _client
        .rpc(
          'cancel_rewatch',
          params: {
            'p_tmdb_id': tmdbId,
            'p_media_type': mediaType,
            'p_next_season': next?.next?.season,
            'p_next_episode': next?.next?.episode,
            'p_next_aired': next?.isAired ?? false,
          },
        )
        .withAppFailure();
    invalidateWatchLogsCache();
    await _cacheReturnedRow(userId, tmdbId, mediaType, rows);
  }

  /// The episode after the show's highest logged one (choosing it needs
  /// TMDB data). Null when nothing is logged or TMDB can't be reached.
  Future<({NextEpisodeInfo? next, bool isAired})?> _episodeAfterHighestLog(
    String userId,
    int tmdbId,
  ) async {
    final highest = await _client
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
    if (highest == null) return null;

    final Map<String, dynamic>? details;
    try {
      details = await _tmdbService.getMediaDetails(tmdbId.toString(), 'tv');
    } catch (e, st) {
      // Safe to go on: without a next episode the server marks the highest
      // logged one as completed, which is still a valid state.
      AppLogger.warn(
        'WatchHistoryRepository',
        'TMDB details for show $tmdbId failed; cancelling the rewatch '
            'without a next episode',
        error: e,
        stackTrace: st,
      );
      return null;
    }
    if (details == null) return null;

    return _seriesService.getNextEpisode(
      details,
      highest['season'] as int? ?? 0,
      highest['episode'] as int? ?? 0,
    );
  }

  Future<void> dropFromContinueWatching(String userId, int tmdbId) async {
    invalidateWatchLogsCache();
    // Update Local
    await (_db.update(_db.localWatchHistories)
          ..where((t) => t.userId.equals(userId) & t.tmdbId.equals(tmdbId)))
        .write(const LocalWatchHistoriesCompanion(status: Value('dropped')));

    // Update Remote
    await _client
        .from('watch_history')
        .update({'status': 'dropped'})
        .eq('user_id', userId)
        .eq('tmdb_id', tmdbId);
  }

  Future<void> restoreToContinueWatching(String userId, int tmdbId) async {
    invalidateWatchLogsCache();
    // Server first: if it fails, the local copy stays as it was (REV-106).
    await _client
        .from('watch_history')
        .update({'status': 'watching'})
        .eq('user_id', userId)
        .eq('tmdb_id', tmdbId)
        .withAppFailure();
    await (_db.update(_db.localWatchHistories)
          ..where((t) => t.userId.equals(userId) & t.tmdbId.equals(tmdbId)))
        .write(const LocalWatchHistoriesCompanion(status: Value('watching')));
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
    invalidateWatchLogsCache();
    await _cacheReturnedRow(userId, tmdbId, mediaType, rows);
  }

  Future<void> removeFromDropped(
    String userId,
    int tmdbId,
    String mediaType,
  ) async {
    invalidateWatchLogsCache();
    await _client
        .from('watch_history')
        .delete()
        .eq('user_id', userId)
        .eq('tmdb_id', tmdbId)
        .eq('status', 'dropped')
        .withAppFailure();
    await _db.deleteWatchHistoryItem(userId, tmdbId, mediaType);
  }

  // Simple StreamTransformer to debounce events
  StreamTransformer<T, T> _debounceTransformer<T>(Duration duration) {
    return StreamTransformer<T, T>.fromBind((Stream<T> stream) {
      // StreamController to manage the debounced stream
      final controller = StreamController<T>.broadcast();
      Timer? debounceTimer;

      stream.listen(
        (data) {
          debounceTimer?.cancel();
          debounceTimer = Timer(duration, () {
            controller.add(data);
          });
        },
        onError: (error) => controller.addError(error),
        onDone: () {
          debounceTimer?.cancel();
          controller.close();
        },
      );

      return controller.stream;
    });
  }
}
