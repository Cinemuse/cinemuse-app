import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:cinemuse_app/core/data/database.dart' hide MediaItem; // Hide conflicting name if any
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepository(supabase, ref.watch(appDatabaseProvider));
});

class MediaRepository {
  final SupabaseClient _client;
  final AppDatabase _db;

  MediaRepository(this._client, this._db);

  /// Default TTL for cached items: 7 days
  static const Duration defaultTTL = Duration(days: 7);

  /// Highly accessed items (trending) TTL: 24 hours
  static const Duration trendingTTL = Duration(hours: 24);

  Future<MediaItem?> getMediaItem(int tmdbId, MediaKind type) async {
    // 1. Try Local Cache (Drift)
    try {
      final localData = await _db.getMediaItem(tmdbId, type.name);
      if (localData != null && localData.expiryDate.isAfter(DateTime.now())) {
        return _mapToMediaItem(localData);
      }
    } catch (e) {
      print('MediaRepository: Local cache fetch failed: $e');
    }

    // 2. Try Supabase Cache
    try {
      final response = await _client
          .from('media_cache')
          .select()
          .eq('tmdb_id', tmdbId)
          .eq('media_type', type.name)
          .maybeSingle();

      if (response != null) {
        final item = MediaItem.fromJson(response);
        // Sync to Local Cache asynchronously
        ensureMediaCached(item).catchError((e) => print('Background sync to local failed: $e'));
        return item;
      }
    } catch (e) {
      print('MediaRepository: Supabase cache fetch failed: $e');
    }

    return null;
  }

  Future<List<MediaItem>> getMediaItems(List<({int id, MediaKind type})> requests) async {
    if (requests.isEmpty) return [];

    try {
      final filters = requests.map((r) => (id: r.id, type: r.type.name)).toList();
      final localResults = await _db.getMediaItems(filters);
      
      return localResults
          .where((data) => data.expiryDate.isAfter(DateTime.now()))
          .map((data) => _mapToMediaItem(data))
          .toList();
    } catch (e) {
      print('MediaRepository: Bulk local cache fetch failed: $e');
      return [];
    }
  }

  /// Ensures a media item exists in both local and remote cache.
  Future<void> ensureMediaCached(MediaItem item, {Duration? ttl}) async {
    final expiry = DateTime.now().add(ttl ?? defaultTTL);
    
    // Save to Local Cache (Drift)
    try {
      await _db.upsertMediaItem(CachedMediaItemsCompanion(
        tmdbId: Value(item.tmdbId),
        mediaType: Value(item.mediaType.name),
        title: Value(item.title),
        posterPath: Value(item.posterPath),
        backdropPath: Value(item.backdropPath),
        runtimeMinutes: Value(item.runtimeMinutes),
        genres: Value(item.genres != null ? jsonEncode(item.genres) : null),
        releaseDate: Value(item.releaseDate),
        voteAverage: Value(item.voteAverage),
        updatedAt: Value(item.updatedAt),
        expiryDate: Value(expiry),
      ));
    } catch (e) {
      print('MediaRepository: Failed to save to local cache: $e');
    }

    // Save to Remote Cache (Supabase)
    try {
      await _client.from('media_cache').upsert(item.toDbJson());
    } catch (e) {
      print('MediaRepository: Failed to sync to remote cache: $e');
    }
  }

  /// Map Drift data to Domain model
  MediaItem _mapToMediaItem(CachedMediaItem data) {
    return MediaItem(
      tmdbId: data.tmdbId,
      mediaType: MediaItem.fromString(data.mediaType),
      title: data.title,
      posterPath: data.posterPath,
      backdropPath: data.backdropPath,
      runtimeMinutes: data.runtimeMinutes,
      genres: data.genres != null ? (jsonDecode(data.genres!) as List).map((e) => e.toString()).toList() : null,
      releaseDate: data.releaseDate,
      voteAverage: data.voteAverage,
      updatedAt: data.updatedAt,
    );
  }

  Future<void> saveMediaItem(MediaItem item) async {
    await ensureMediaCached(item);
  }
}
