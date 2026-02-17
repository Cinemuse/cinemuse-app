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
        .asyncMap((event) async {
          // Since stream doesn't support joins easily, we fetch full details if needed
          // Or we can rely on basic data. For now, let's fetch linked media items
          // This is a bit heavy, but ensures we have media details.
          // Alternative: We can fetch media_cache separately or rely on client-side join.
          // Optimization: Fetch all media_cache items once and join in memory? 
          // For now simplicity: Let's refetch current snapshot with join
          
          final ids = event.map((e) => e['tmdb_id'] as int).toList();
          if (ids.isEmpty) return [];

          final response = await _client
            .from('watch_history')
            .select('*, media_cache(*)')
            .eq('user_id', userId)
            .inFilter('tmdb_id', ids)
            .order('last_watched_at', ascending: false);
            
          return (response as List).map((e) => WatchHistory.fromJson(e)).toList();
        });
  }

  // Stream series logs for a specific user and tmdbId
  Stream<List<Map<String, dynamic>>> watchSeriesLogs(String userId, int tmdbId) {
    return _client
        .from('watch_logs')
        .stream(primaryKey: ['id'])
        .eq('tmdb_id', tmdbId)
        .order('logged_at', ascending: false)
        .map((list) => list.where((item) => 
            item['user_id'] == userId && 
            item['media_type'] == 'tv'
        ).toList());
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
  }

  Future<void> removeFromContinueWatching(String userId, int tmdbId) async {
    await _client
        .from('watch_history')
        .delete()
        .eq('user_id', userId)
        .eq('tmdb_id', tmdbId);
  }
}
