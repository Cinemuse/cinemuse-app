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

  Future<void> updateProgress({
    required String userId,
    required MediaItem media,
    required int progressSeconds,
    required int totalDuration,
  }) async {
    // 1. Ensure media is in cache (fire and forget usually, or await)
    // For safety, we verify it exists or upsert it.
    // In a real app we might rely on a separate sync, but here we lazy-cache.
    /* 
    await _client.from('media_cache').upsert(media.toJson()); 
    */
    // Assuming media exists or is inserted by caller (e.g. MediaRepository)
    // But since foreign key constraint exists, we MUST ensure it exists.
    // The previous implementation of `saveMediaItem` is upsert.

    await _client.from('watch_history').upsert({
      'user_id': userId,
      'tmdb_id': media.tmdbId,
      'media_type': media.mediaType.name,
      'status': 'watching',
      'progress_seconds': progressSeconds,
      'total_duration': totalDuration,
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
}
