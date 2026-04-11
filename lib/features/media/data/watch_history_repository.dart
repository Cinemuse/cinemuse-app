import 'dart:async';
import 'package:cinemuse_app/core/error/supabase_extensions.dart';
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

final watchHistoryRepositoryProvider = Provider<WatchHistoryRepository>((ref) {
  return WatchHistoryRepository(
    supabase, 
    ref.watch(mediaRepositoryProvider),
    ref.watch(appDatabaseProvider),
    ref.watch(seriesDomainServiceProvider),
  );
});

class WatchHistoryRepository {
  final SupabaseClient _client;
  final MediaRepository _mediaRepo;
  final AppDatabase _db;
  final SeriesDomainService _seriesService;

  WatchHistoryRepository(this._client, this._mediaRepo, this._db, this._seriesService);

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

  /// Ensures a media item exists in the local cache.
  Future<void> saveMediaItem(MediaItem media) async {
    await _mediaRepo.saveMediaItem(media);
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
    if (remainingSeconds < PlaybackThresholds.completionRemainingSeconds || progressPercentage > PlaybackThresholds.completionPercentage) {
      // Remove from "Continue Watching"
      final deleted = await _client.from('watch_history').delete().match({
        'user_id': userId,
        'tmdb_id': media.tmdbId,
        'media_type': media.mediaType.name,
        'season': season ?? 0,
        'episode': episode ?? 0,
      }).select().withErrorHandling();

      // Only proceed if we actually deleted something (prevents double logs)
      // or if we are marking a new completion without an existing history entry
      if ((deleted as List).isNotEmpty) {
        // Update local DB instantly
        await _db.deleteWatchHistoryItem(userId, media.tmdbId, media.mediaType.name, season: season ?? 0, episode: episode ?? 0);

        // [MODIFIED] Only log if not already watched
        final alreadyWatched = await isMediaAlreadyWatched(
          userId: userId,
          tmdbId: media.tmdbId,
          mediaType: media.mediaType.name,
          season: season ?? 0,
          episode: episode ?? 0,
        );

        if (!alreadyWatched) {
          // Mark as Completed in logs (synonymous with checkmark in Cinemuse)
          await logEpisodeWatch(
            userId: userId,
            tmdbId: media.tmdbId,
            mediaType: media.mediaType.name,
            season: season ?? 0,
            episode: episode ?? 0,
            durationWatched: progressSeconds,
          );
        }

        // Auto-advance to next episode
        if (media.mediaType == MediaKind.tv && season != null && episode != null && seriesDetails != null) {
          await upsertNextEpisode(
            userId: userId,
            tmdbId: media.tmdbId,
            currentSeason: season,
            currentEpisode: episode,
            seriesDetails: seriesDetails,
          );
        }
      }
      return;
    }

    // 2. Check for Peeking State
    // Watched < 120s AND Watched < 10%
    if (progressSeconds < PlaybackThresholds.peekingSeconds && progressPercentage < PlaybackThresholds.peekingPercentage) {
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
    await _db.upsertWatchHistory(LocalWatchHistoriesCompanion(
      userId: Value(userId),
      tmdbId: Value(media.tmdbId),
      mediaType: Value(media.mediaType.name),
      status: Value('watching'),
      progressSeconds: Value(progressSeconds),
      totalDuration: Value(totalDuration),
      season: Value(season ?? 0),
      episode: Value(episode ?? 0),
      lastWatchedAt: Value(DateTime.now()),
    ));

    // Update Remote
    await _client.from('watch_history').upsert(entry).withErrorHandling();
  }

  Future<bool> isMediaAlreadyWatched({
    required String userId,
    required int tmdbId,
    required String mediaType,
    required int season,
    required int episode,
  }) async {
    final response = await _client
        .from('watch_logs')
        .select('id')
        .eq('user_id', userId)
        .eq('tmdb_id', tmdbId)
        .eq('media_type', mediaType)
        .eq('season', season)
        .eq('episode', episode)
        .limit(1)
        .maybeSingle();
    
    return response != null;
  }

  Future<void> logEpisodeWatch({
    required String userId,
    required int tmdbId,
    required String mediaType,
    required int season,
    required int episode,
    DateTime? loggedAt,
    int? durationWatched,
  }) async {
    await _client.from('watch_logs').insert({
      'user_id': userId,
      'tmdb_id': tmdbId,
      'media_type': mediaType,
      'season': season,
      'episode': episode,
      'logged_at': (loggedAt ?? DateTime.now()).toIso8601String(),
      'duration_watched_seconds': durationWatched,
    }).withErrorHandling();
  }

  Future<void> markAsCompleted({
    required String userId,
    required MediaItem media,
    required int durationWatched,
    DateTime? loggedAt,
  }) async {
    final now = (loggedAt ?? DateTime.now()).toIso8601String();

    await _client.from('watch_logs').insert({
      'user_id': userId,
      'tmdb_id': media.tmdbId,
      'media_type': media.mediaType.name,
      'logged_at': now,
      'duration_watched_seconds': durationWatched,
    }).withErrorHandling();
  }

  Future<WatchHistory?> getHistoryItem(String userId, String tmdbId) async {
    final response = await _client
        .from('watch_history')
        .select()
        .eq('user_id', userId)
        .eq('tmdb_id', tmdbId)
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
          orElse: () => MediaKind.movie
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

      return await Future.wait(futures);
    });
  }

  /// Syncs watch history from Supabase to Drift.
  /// Should be called on app startup or periodically.
  Future<void> syncWatchHistory(String userId) async {
    try {
      final remoteData = await _client
          .from('watch_history')
          .select()
          .eq('user_id', userId)
          .withErrorHandling();

      final companions = (remoteData as List).map((json) {
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
      }).toList();

      await _db.syncWatchHistory(userId, companions);
    } catch (_) {}
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
        .eq('user_id', userId)
        .order('logged_at', ascending: false)
        .withErrorHandling()
        .transform(_debounceTransformer(const Duration(milliseconds: 300)))
        .map((list) => list.where((item) => 
            item['tmdb_id'] == tmdbId && 
            item['media_type'] == 'movie'
        ).toList());
  }

  // Stream series logs for a specific user and tmdbId
  Stream<List<Map<String, dynamic>>> watchSeriesLogs(String userId, int tmdbId) {
    return _client
        .from('watch_logs')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('logged_at', ascending: false)
        .withErrorHandling()
        .transform(_debounceTransformer(const Duration(milliseconds: 300)))
        .map((list) => list.where((item) => 
            item['tmdb_id'] == tmdbId && 
            item['media_type'] == 'tv'
        ).toList());
  }

  // Stream watch_history (progress) for a specific series
  Stream<List<WatchHistory>> watchSeriesHistory(String userId, int tmdbId) {
    return watchHistory(userId).map((list) => list
        .where((e) => e.tmdbId == tmdbId)
        .toList());
  }

  // Get all watch logs for a specific series
  Future<List<Map<String, dynamic>>> getSeriesWatchLogs(String userId, int tmdbId) async {
    final response = await _client
        .from('watch_logs')
        .select('season, episode, logged_at')
        .eq('user_id', userId)
        .eq('tmdb_id', tmdbId)
        .eq('media_type', 'tv')
        .order('logged_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> deleteLatestMovieLog({
    required String userId,
    required int tmdbId,
  }) async {
    final response = await _client
        .from('watch_logs')
        .select('id')
        .eq('user_id', userId)
        .eq('tmdb_id', tmdbId)
        .eq('media_type', 'movie')
        .order('logged_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response != null && response['id'] != null) {
      await _client
          .from('watch_logs')
          .delete()
          .eq('id', response['id']);
      
      await _syncLogHistory(userId, tmdbId, 'movie');
    }
  }

  Future<void> deleteAllMovieLogs({
    required String userId,
    required int tmdbId,
  }) async {
    await _client
        .from('watch_logs')
        .delete()
        .eq('user_id', userId)
        .eq('tmdb_id', tmdbId)
        .eq('media_type', 'movie');

    await _syncLogHistory(userId, tmdbId, 'movie');
  }

  Future<void> logMovieWatch({
    required String userId,
    required int tmdbId,
    DateTime? loggedAt,
  }) async {
    await _client.from('watch_logs').insert({
      'user_id': userId,
      'tmdb_id': tmdbId,
      'media_type': 'movie',
      'season': 0,
      'episode': 0,
      'logged_at': (loggedAt ?? DateTime.now()).toIso8601String(),
    }).withErrorHandling();

    // After logging, update the history to 'completed'
    final historyUpdate = {
      'user_id': userId,
      'tmdb_id': tmdbId,
      'media_type': 'movie',
      'status': 'completed',
      'progress_seconds': 0,
      'total_duration': 0,
      'season': 0,
      'episode': 0,
      'last_watched_at': (loggedAt ?? DateTime.now()).toIso8601String(),
    };
    await _client.from('watch_history').upsert(historyUpdate);

    // Update local DB instantly
    await _db.upsertWatchHistory(LocalWatchHistoriesCompanion(
      userId: Value(userId),
      tmdbId: Value(tmdbId),
      mediaType: const Value('movie'),
      status: const Value('completed'),
      progressSeconds: const Value(0),
      totalDuration: const Value(0),
      season: const Value(0),
      episode: const Value(0),
      lastWatchedAt: Value(loggedAt ?? DateTime.now()),
    ));
  }

  Future<void> deleteLatestEpisodeLog({
    required String userId,
    required int tmdbId,
    required int season,
    required int episode,
  }) async {
    // 1. Get the latest log ID for this specific episode
    final response = await _client
        .from('watch_logs')
        .select('id')
        .eq('user_id', userId)
        .eq('tmdb_id', tmdbId)
        .eq('season', season)
        .eq('episode', episode)
        .order('logged_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response != null && response['id'] != null) {
      // 2. Delete that specific log entry
      await _client
          .from('watch_logs')
          .delete()
          .eq('id', response['id']);
      
      // 3. Manually sync history since trigger handles inserts but maybe not deletions
      await _syncLogHistory(userId, tmdbId, 'tv');
    }
  }

  Future<void> deleteAllEpisodeLogs({
    required String userId,
    required int tmdbId,
    required int season,
    required int episode,
  }) async {
    await _client
        .from('watch_logs')
        .delete()
        .eq('user_id', userId)
        .eq('tmdb_id', tmdbId)
        .eq('season', season)
        .eq('episode', episode);

    await _syncLogHistory(userId, tmdbId, 'tv');
  }

  /// Helper to ensure watch_history table stays in sync after deletions
  Future<void> _syncLogHistory(String userId, int tmdbId, String mediaType) async {
    // 1. Remote: Find the new "latest" log
    final latest = await _client
        .from('watch_logs')
        .select()
        .eq('user_id', userId)
        .eq('tmdb_id', tmdbId)
        .eq('media_type', mediaType)
        .order('logged_at', ascending: false)
        .limit(1)
        .maybeSingle();

    // 2. Clear history for this show/movie first (Remote & Local)
    // This removes any "ghost" entries (e.g. the one we just untracked)
    await _client.from('watch_history').delete().match({
      'user_id': userId,
      'tmdb_id': tmdbId,
      'media_type': mediaType,
    });
    await _db.deleteWatchHistoryItem(userId, tmdbId, mediaType);

    if (latest != null) {
      // Revert history to this latest log
      final dateStr = latest['logged_at'];
      final date = dateStr != null ? DateTime.parse(dateStr) : DateTime.now();

      final historyUpdate = {
        'user_id': userId,
        'tmdb_id': tmdbId,
        'media_type': mediaType,
        'season': latest['season'],
        'episode': latest['episode'],
        'last_watched_at': dateStr,
        'status': 'watching', 
      };

      await _client.from('watch_history').upsert(historyUpdate);

      // Update local DB
      await _db.upsertWatchHistory(LocalWatchHistoriesCompanion(
        userId: Value(userId),
        tmdbId: Value(tmdbId),
        mediaType: Value(mediaType),
        status: const Value('watching'),
        progressSeconds: const Value(0),
        totalDuration: const Value(0),
        season: Value(latest['season'] as int? ?? 0),
        episode: Value(latest['episode'] as int? ?? 0),
        lastWatchedAt: Value(date),
      ));
    }
  }

  Future<void> logMultipleEpisodes({
    required String userId,
    required int tmdbId,
    required List<({int season, int episode})> episodes,
    DateTime? loggedAt,
  }) async {
    if (episodes.isEmpty) return;

    final now = (loggedAt ?? DateTime.now()).toIso8601String();

    final logs = episodes.map((e) => {
      'user_id': userId,
      'tmdb_id': tmdbId,
      'media_type': 'tv',
      'season': e.season,
      'episode': e.episode,
      'logged_at': now,
    }).toList();

    await _client.from('watch_logs').insert(logs);

    // 3. Update history for all marked episodes to completed
    final historyUpdates = episodes.map((e) => {
      'user_id': userId,
      'tmdb_id': tmdbId,
      'media_type': 'tv',
      'status': 'completed',
      'progress_seconds': 0, // We set to 0/0 or matching if 0 is treated as finished
      'total_duration': 0,
      'season': e.season,
      'episode': e.episode,
      'last_watched_at': now,
    }).toList();

    await _client.from('watch_history').upsert(historyUpdates);

    // Update local DB
    final nowTime = loggedAt ?? DateTime.now();
    await _db.batch((batch) {
      for (final e in episodes) {
        batch.insert(
          _db.localWatchHistories,
          LocalWatchHistoriesCompanion(
            userId: Value(userId),
            tmdbId: Value(tmdbId),
            mediaType: const Value('tv'),
            status: const Value('completed'),
            progressSeconds: const Value(0),
            totalDuration: const Value(0),
            season: Value(e.season),
            episode: Value(e.episode),
            lastWatchedAt: Value(nowTime),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// Sets the "next" episode as watching with 0 progress in history.
  /// Used to auto-advance the "Continue Watching" row.
  Future<void> upsertNextEpisode({
    required String userId,
    required int tmdbId,
    required int currentSeason,
    required int currentEpisode,
    required Map<String, dynamic> seriesDetails,
  }) async {
    // 1. Calculate next episode using Domain Service
    final result = _seriesService.getNextEpisode(
      seriesDetails, 
      currentSeason, 
      currentEpisode,
    );
    
    final nextEpisodeInfo = result.next;
    final isAired = result.isAired;
    
    if (nextEpisodeInfo != null) {
      if (!isAired) {
        // Next episode hasn't aired yet.
        // Mark the CURRENT episode as 'completed' in watch_history so we have a record for the sync service.
        final caughtUpEntry = {
          'user_id': userId,
          'tmdb_id': tmdbId,
          'media_type': 'tv',
          'season': currentSeason,
          'episode': currentEpisode,
          'status': 'completed',
          'progress_seconds': 0,
          'total_duration': 0,
          'last_watched_at': DateTime.now().toIso8601String(),
        };

        // Update Local
        await _db.upsertWatchHistory(LocalWatchHistoriesCompanion(
          userId: Value(userId),
          tmdbId: Value(tmdbId),
          mediaType: Value('tv'),
          season: Value(currentSeason),
          episode: Value(currentEpisode),
          status: Value('completed'),
          progressSeconds: Value(0),
          totalDuration: Value(0),
          lastWatchedAt: Value(DateTime.now()),
        ));

        // Update Remote
        await _client.from('watch_history').upsert(caughtUpEntry);
        return;
      }

      final entry = {
        'user_id': userId,
        'tmdb_id': tmdbId,
        'media_type': 'tv',
        'season': nextEpisodeInfo.season,
        'episode': nextEpisodeInfo.episode,
        'status': 'watching',
        'progress_seconds': 0,
        'total_duration': 0,
        'last_watched_at': DateTime.now().toIso8601String(),
      };

      // Update Local
      await _db.upsertWatchHistory(LocalWatchHistoriesCompanion(
        userId: Value(userId),
        tmdbId: Value(tmdbId),
        mediaType: Value('tv'),
        season: Value(nextEpisodeInfo.season),
        episode: Value(nextEpisodeInfo.episode),
        status: Value('watching'),
        progressSeconds: Value(0),
        totalDuration: Value(0),
        lastWatchedAt: Value(DateTime.now()),
      ));

      // Update Remote
      await _client.from('watch_history').upsert(entry);
    }
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
      await _db.upsertWatchHistory(LocalWatchHistoriesCompanion(
        userId: Value(userId),
        tmdbId: Value(tmdbId),
        mediaType: Value('tv'),
        season: Value(season),
        episode: Value(episode),
        status: Value('watching'),
        progressSeconds: Value(0),
        totalDuration: Value(0),
        lastWatchedAt: Value(DateTime.now()),
      ));

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

  Future<void> deleteAllSeriesLogs({
    required String userId,
    required int tmdbId,
  }) async {
    await _client
        .from('watch_logs')
        .delete()
        .eq('user_id', userId)
        .eq('tmdb_id', tmdbId)
        .eq('media_type', 'tv');

    // Also clear from watch_history (sync will handle it since no logs left)
    await _syncLogHistory(userId, tmdbId, 'tv');
  }

  Future<void> removeFromContinueWatching(String userId, int tmdbId) async {
    // Update Local
    await (_db.delete(_db.localWatchHistories)
          ..where((t) => t.userId.equals(userId) & t.tmdbId.equals(tmdbId)))
        .go();

    // Update Remote
    await _client
        .from('watch_history')
        .delete()
        .eq('user_id', userId)
        .eq('tmdb_id', tmdbId);
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
  }}
