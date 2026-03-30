import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:cinemuse_app/core/data/database.dart' hide MediaItem; 
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
          .map<MediaItem>((data) => mapToMediaItem(data))
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

  /// Fetches full metadata from TMDB and updates the cache.
  Future<void> repairMetadata(int tmdbId, MediaKind type) async {
    final key = '${type.name}-$tmdbId';
    if (_repairQueue.contains(key)) return;
    
    print('DEBUG: 🔧 Starting metadata repair for $tmdbId ($type)');
    _repairQueue.add(key);
    try {
      final details = await _tmdbService.getMediaDetails(tmdbId.toString(), type.name);
      
      MediaItem item;
      if (details != null) {
        final titleIt = MediaItem.extractTitleFromTmdb(details, 'it');
        final titleEn = MediaItem.extractTitleFromTmdb(details, 'en');
        final cast = (details['credits']?['cast'] as List?)?.take(10).map((c) => c['id'] as int).toList();

        item = MediaItem(
          tmdbId: tmdbId,
          mediaType: type,
          titleIt: titleIt,
          titleEn: titleEn,
          posterPath: details['poster_path'],
          backdropPath: details['backdrop_path'],
          runtimeMinutes: details['runtime'] ?? (details['episode_run_time'] is List && (details['episode_run_time'] as List).isNotEmpty ? details['episode_run_time'][0] : null),
          genres: details['genres'] is List 
              ? (details['genres'] as List).map((e) => e['id'] as int).toList()
              : null,
          castMembers: cast,
          releaseDate: DateTime.tryParse(details['release_date'] ?? details['first_air_date'] ?? ''),
          voteAverage: (details['vote_average'] as num?)?.toDouble(),
          updatedAt: DateTime.now(),
        );
      } else {
        // Negative Caching: Save a stub record so we don't spam TMDB for 24h
        print('DEBUG: ❌ TMDB 404/Null for $tmdbId. Caching negative result for 24h.');
        item = MediaItem(
          tmdbId: tmdbId,
          mediaType: type,
          updatedAt: DateTime.now(),
        );
      }

      await ensureMediaCached(item);
    } catch (e) {
      print('DEBUG: ⚠️ Repair error for $tmdbId: $e');
      // Even on error, we might want to cache a stub to prevent immediate retry
    } finally {
      _repairQueue.remove(key);
    }
  }
}
