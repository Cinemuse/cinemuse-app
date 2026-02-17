import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cinemuse_app/core/services/supabase_service.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';

final watchHistoryRepositoryProvider = Provider<WatchHistoryRepository>((ref) {
  return WatchHistoryRepository(supabase);
});

class WatchHistoryRepository {
  final SupabaseClient _client;

  WatchHistoryRepository(this._client);

  // Get current "Continue Watching" list (status = watching)
  Future<List<WatchHistory>> getContinueWatching(String userId) async {
    final response = await _client
        .from('watch_history')
        .select('*, media_cache(*)') // Join with media_cache
        .eq('user_id', userId)
        .eq('status', 'watching')
        .order('last_watched_at', ascending: false);

    return (response as List).map((e) => WatchHistory.fromJson(e)).toList();
  }

  /// Ensures a media item exists in the cache. 
  /// Should be called during "natural" retrieval (e.g., when initializing details or player).
  Future<void> ensureMediaCached(MediaItem media) async {
    try {
      await _client.from('media_cache').upsert(media.toDbJson());
    } catch (e) {
      print('Error caching media: $e'); 
    }
  }

  Future<void> updateProgress({
    required String userId,
    required MediaItem media,
    required int progressSeconds,
    required int totalDuration,
    int? season,
    int? episode,
  }) async {
    await _client.from('watch_history').upsert({
      'user_id': userId,
      'tmdb_id': media.tmdbId, 
      'media_type': media.mediaType.name,
      'status': 'watching',
      'progress_seconds': progressSeconds,
      'total_duration': totalDuration,
      'season': season ?? 0,
      'episode': episode ?? 0,
      'last_watched_at': DateTime.now().toIso8601String(),
    });
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
    });
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
    });
  }

  Future<WatchHistory?> getHistoryItem(String userId, String tmdbId) async {
    final response = await _client
        .from('watch_history')
        .select('*, media_cache(*)')
        .eq('user_id', userId)
        .eq('tmdb_id', tmdbId)
        .maybeSingle();

    if (response == null) return null;
    return WatchHistory.fromJson(response);
  }

  // Stream all watch history for the user (Global Store Listener)
  Stream<List<WatchHistory>> watchAllHistory(String userId) {
    return _client
        .from('watch_history')
        .stream(primaryKey: ['user_id', 'tmdb_id', 'media_type', 'season', 'episode'])
        .eq('user_id', userId)
        .order('last_watched_at', ascending: false)
        .transform(_debounceTransformer(const Duration(milliseconds: 300)))
        .asyncMap((event) async {
          if (event.isEmpty) return <WatchHistory>[];

          // 1. Extract IDs from the stream event (which contains the latest watch_history data)
          final ids = event.map((e) => e['tmdb_id'] as int).toList();
          
          // 2. Fetch only the necessary media details from media_cache
          final mediaCacheResponse = await _client
            .from('media_cache')
            .select('*')
            .inFilter('tmdb_id', ids);
            
          final mediaMap = {
            for (var m in (mediaCacheResponse as List)) 
              m['tmdb_id'] as int: m
          };

          // 3. Merge the stream data with the fetched media details
          return event.map((e) {
            final tmdbId = e['tmdb_id'] as int;
            final mediaData = mediaMap[tmdbId];
            
            // Create a comprehensive map merging history and media data
            final mergedData = Map<String, dynamic>.from(e);
            if (mediaData != null) {
              mergedData['media_cache'] = mediaData;
            }
            
            return WatchHistory.fromJson(mergedData);
          }).toList();
        });
  }

  // Stream series logs for a specific user and tmdbId
  Stream<List<Map<String, dynamic>>> watchSeriesLogs(String userId, int tmdbId) {
    return _client
        .from('watch_logs')
        .stream(primaryKey: ['id'])
        .eq('tmdb_id', tmdbId)
        .order('logged_at', ascending: false)
        .transform(_debounceTransformer(const Duration(milliseconds: 300)))
        .map((list) => list.where((item) => 
            item['user_id'] == userId && 
            item['media_type'] == 'tv'
        ).toList());
  }

  // Stream watch_history (progress) for a specific series
  Stream<List<WatchHistory>> watchSeriesHistory(String userId, int tmdbId) {
    return _client
        .from('watch_history')
        .stream(primaryKey: ['user_id', 'tmdb_id', 'media_type', 'season', 'episode'])
        .eq('user_id', userId)
        .map((list) => list
            .where((e) => e['tmdb_id'] == tmdbId)
            .map((e) => WatchHistory.fromJson(e))
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
    // Find the new "latest" log
    final latest = await _client
        .from('watch_logs')
        .select()
        .eq('user_id', userId)
        .eq('tmdb_id', tmdbId)
        .eq('media_type', mediaType)
        .order('logged_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (latest == null) {
      // No logs left -> Remove from history
      await _client
          .from('watch_history')
          .delete()
          .eq('user_id', userId)
          .eq('tmdb_id', tmdbId)
          .eq('media_type', mediaType);
    } else {
      // Revert history to this log
      // Note: We default to 'watching' status as we don't know if it's completed from here
      await _client.from('watch_history').upsert({
        'user_id': userId,
        'tmdb_id': tmdbId,
        'media_type': mediaType,
        'season': latest['season'],
        'episode': latest['episode'],
        'last_watched_at': latest['logged_at'],
        'status': 'watching', 
      });
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
    // 1. Calculate next episode
    int? nextSeason;
    int? nextEpisode;
    
    final seasons = seriesDetails['seasons'] as List? ?? [];
    // Find current season info
    final currentSeasonData = seasons.firstWhere(
      (s) => s['season_number'] == currentSeason, 
      orElse: () => null
    );
    
    if (currentSeasonData != null) {
      final episodeCount = currentSeasonData['episode_count'] as int? ?? 0;
      if (currentEpisode < episodeCount) {
        // Next episode in same season
        nextSeason = currentSeason;
        nextEpisode = currentEpisode + 1;
      } else {
        // Next season?
        // Find next season number
        // Assuming seasons are not necessarily sorted or sequential, filter for > currentSeason
        // and take the smallest one.
        final nextSeasons = seasons
            .map((s) => s['season_number'] as int? ?? 0)
            .where((n) => n > currentSeason)
            .toList()
          ..sort();
          
        if (nextSeasons.isNotEmpty) {
          nextSeason = nextSeasons.first;
          nextEpisode = 1; 
        }
      }
    }
    
    if (nextSeason != null && nextEpisode != null) {
      await _client.from('watch_history').upsert({
        'user_id': userId,
        'tmdb_id': tmdbId,
        'media_type': 'tv',
        'season': nextSeason,
        'episode': nextEpisode,
        'status': 'watching', // Set as watching so it appears in "Continue Watching"
        'progress_seconds': 0,
        'total_duration': 0, // Placeholder
        'last_watched_at': DateTime.now().toIso8601String(),
      });
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

      final subscription = stream.listen(
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
