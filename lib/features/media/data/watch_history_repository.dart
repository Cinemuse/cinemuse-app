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
    // Note: We no longer automatically upsert to media_cache here 
    // to avoid redundant network hits during frequent progress saves.
    // The caller should call ensureMediaCached() once during initialization.

    await _client.from('watch_history').upsert({
      'user_id': userId,
      'tmdb_id': media.tmdbId,
      'media_type': media.mediaType.name,
      'status': 'watching',
      'progress_seconds': progressSeconds,
      'total_duration': totalDuration,
      'season': season,
      'episode': episode,
      'last_watched_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> markAsCompleted({
    required String userId,
    required MediaItem media,
    required int durationWatched,
  }) async {
    // Insert into Logs -> Trigger updates History
    await _client.from('watch_logs').insert({
      'user_id': userId,
      'tmdb_id': media.tmdbId,
      'media_type': media.mediaType.name,
      'logged_at': DateTime.now().toIso8601String(),
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
        .stream(primaryKey: ['id'])
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
  Future<void> removeFromContinueWatching(String userId, int tmdbId) async {
    await _client
        .from('watch_history')
        .delete()
        .eq('user_id', userId)
        .eq('tmdb_id', tmdbId);
  }
}
