import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:cinemuse_app/core/data/database.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/services/media/tmdb_service.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(tmdbServiceProvider),
  );
});

class MediaRepository {
  final AppDatabase _db;
  final TmdbService _tmdbService;

  /// Session-based in-memory cache
  final Map<String, MediaItem> _memoryCache = {};

  MediaRepository(this._db, this._tmdbService);

  /// Default TTL for cached items: 7 days
  static const Duration defaultTTL = Duration(days: 7);

  /// Highly accessed items (trending) TTL: 24 hours
  static const Duration trendingTTL = Duration(hours: 24);

  Future<MediaItem?> getMediaItem(int tmdbId, MediaKind type) async {
    final key = '${type.name}-$tmdbId';
    
    // 1. Check memory cache
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }

    // 2. Try Local Cache (Drift)
    try {
      final localData = await _db.getMediaItem(tmdbId, type.name);
      if (localData != null) {
        final item = mapToMediaItem(localData);
        _memoryCache[key] = item;
        return item;
      }
    } catch (_) {}

    // 3. Fallback to TMDB
    try {
      final details = await _tmdbService.getMediaDetails(tmdbId.toString(), type.name);
      if (details != null) {
        final item = MediaItem.fromTmdbDetails(details, type);
        // Save to cache (memory and local)
        await saveMediaItem(item);
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
          .map<MediaItem>((data) => mapToMediaItem(data))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Ensures a media item exists in the local cache.
  Future<void> saveMediaItem(MediaItem item) async {
    final key = '${item.mediaType.name}-${item.tmdbId}';
    
    // Update memory
    _memoryCache[key] = item;

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
      ));
    } catch (_) {}
  }

  /// Alias for compatibility
  Future<void> ensureMediaCached(MediaItem item) async {
    await saveMediaItem(item);
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

}
