import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:cinemuse_app/core/data/database.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cinemuse_app/core/services/media/tmdb_service.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepository(
    supabase, 
    ref.watch(appDatabaseProvider),
    ref.watch(tmdbServiceProvider),
  );
});

class MediaRepository {
  final SupabaseClient _client;
  final AppDatabase _db;
  final TmdbService _tmdbService;

  MediaRepository(this._client, this._db, this._tmdbService);

  /// Default TTL for cached items: 7 days
  static const Duration defaultTTL = Duration(days: 7);

  /// Highly accessed items (trending) TTL: 24 hours
  static const Duration trendingTTL = Duration(hours: 24);

  Future<MediaItem?> getMediaItem(int tmdbId, MediaKind type) async {
    // 1. Try Local Cache (Drift)
    try {
      final localData = await _db.getMediaItem(tmdbId, type.name);
      if (localData != null && localData.expiryDate.isAfter(DateTime.now())) {
        return mapToMediaItem(localData);
      }
    } catch (_) {}

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
        ensureMediaCached(item).catchError((_) {});
        return item;
      }
    } catch (_) {}

    return null;
  }

  Future<List<MediaItem>> getMediaItems(List<({int id, MediaKind type})> requests) async {
    if (requests.isEmpty) return [];

    try {
      final filters = requests.map((r) => (id: r.id, type: r.type.name)).toList();
      final localResults = await _db.getMediaItems(filters);
      
      return localResults
          .where((data) => data.expiryDate.isAfter(DateTime.now()))
          .map<MediaItem>((data) => mapToMediaItem(data))
          .toList();
    } catch (_) {
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
        titleIt: Value(item.titleIt),
        titleEn: Value(item.titleEn),
        posterPath: Value(item.posterPath),
        backdropPath: Value(item.backdropPath),
        runtimeMinutes: Value(item.runtimeMinutes),
        genres: Value(item.genres != null ? jsonEncode(item.genres) : null),
        castMembers: Value(item.castMembers != null ? jsonEncode(item.castMembers) : null),
        releaseDate: Value(item.releaseDate),
        voteAverage: Value(item.voteAverage),
        updatedAt: Value(item.updatedAt),
        expiryDate: Value(expiry),
      ));
    } catch (_) {}

    // Save to Remote Cache (Supabase)
    try {
      await _client.from('media_cache').upsert(item.toDbJson());
    } catch (_) {}
  }

  /// Map Drift data to Domain model
  MediaItem mapToMediaItem(CachedMediaItem data) {
    return MediaItem(
      tmdbId: data.tmdbId,
      mediaType: MediaKind.values.firstWhere((e) => e.name == data.mediaType, orElse: () => MediaKind.movie),
      titleIt: data.titleIt == null || data.titleIt!.trim().isEmpty ? null : data.titleIt,
      titleEn: data.titleEn == null || data.titleEn!.trim().isEmpty ? null : data.titleEn,
      posterPath: data.posterPath,
      backdropPath: data.backdropPath,
      runtimeMinutes: data.runtimeMinutes,
      genres: data.genres != null ? (jsonDecode(data.genres!) as List).cast<int>() : null,
      castMembers: data.castMembers != null ? (jsonDecode(data.castMembers!) as List).cast<int>() : null,
      releaseDate: data.releaseDate,
      voteAverage: data.voteAverage,
      updatedAt: data.updatedAt,
    );
  }

  Future<void> saveMediaItem(MediaItem item) async {
    await ensureMediaCached(item);
  }

  /// Internal set to track items currently being repaired to avoid redundant API calls.
  final Set<String> _repairQueue = {};

  /// Internal set to track items currently being fetched from TMDB by ANY service
  /// to avoid redundant parallel network calls.
  final Set<String> _activeFetches = {};

  /// Updates the metadata cache from raw TMDB details.
  /// Call this whenever you fetch full details from TMDB to sync the cache
  /// and potentially prevent background repairs.
  Future<void> ingestTmdbDetails(Map<String, dynamic> details, MediaKind type) async {
    final id = details['id']?.toString();
    if (id == null) return;
    
    final tmdbId = int.parse(id);
    final key = '${type.name}-$tmdbId';
    
    // If we are already repairing this item, we don't need to do anything here
    // as ensureMediaCached will handle the upsert.
    if (_repairQueue.contains(key)) return;

    final item = MediaItem.fromTmdbDetails(details, type);
    await ensureMediaCached(item);
  }

  /// Fetches full metadata from TMDB and updates the cache.
  Future<void> repairMetadata(int tmdbId, MediaKind type) async {
    final key = '${type.name}-$tmdbId';
    if (_repairQueue.contains(key) || _activeFetches.contains(key)) return;
    
    // debugPrint('🔧 Starting metadata repair for $tmdbId ($type)');
    _repairQueue.add(key);
    _activeFetches.add(key);
    try {
      final details = await _tmdbService.getMediaDetails(tmdbId.toString(), type.name);
      
      MediaItem item;
      if (details != null) {
        item = MediaItem.fromTmdbDetails(details, type);
      } else {
        // Negative Caching: Save a stub record so we don't spam TMDB for 24h
        // debugPrint('❌ TMDB 404/Null for $tmdbId. Caching negative result for 24h.');
        item = MediaItem(
          tmdbId: tmdbId,
          mediaType: type,
          updatedAt: DateTime.now(),
        );
      }

      await ensureMediaCached(item);
    } catch (e) {
      // debugPrint('⚠️ Repair error for $tmdbId: $e');
      // Even on error, we might want to cache a stub to prevent immediate retry
    } finally {
      _repairQueue.remove(key);
      _activeFetches.remove(key);
    }
  }

  /// Marks an item as being fetched externally (e.g. by a provider) 
  /// so repairMetadata won't overlap.
  void markAsExternalFetch(int tmdbId, MediaKind type, bool active) {
    final key = '${type.name}-$tmdbId';
    if (active) {
      _activeFetches.add(key);
    } else {
      _activeFetches.remove(key);
    }
  }
}
