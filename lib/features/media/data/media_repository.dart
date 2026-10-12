import 'dart:convert';
import 'dart:developer' as developer;
import 'package:drift/drift.dart';
import 'package:cinemuse_app/core/data/database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/error/supabase_failure.dart';

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(tmdbServiceProvider),
    Supabase.instance.client,
  );
});

class MediaRepository {
  final AppDatabase _db;
  final TmdbService _tmdbService;
  final SupabaseClient _supabase;

  /// Session-based in-memory cache
  final Map<String, MediaItem> _memoryCache = {};

  MediaRepository(this._db, this._tmdbService, this._supabase);

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
        final item = _mapToMediaItem(localData);
        _memoryCache[key] = item;
        return item;
      }
    } catch (e, s) {
      developer.log(
        'Failed to read media item ($tmdbId, ${type.name}) from Drift cache',
        name: 'MediaRepository',
        error: e,
        stackTrace: s,
      );
    }

    // 3. Fallback to TMDB
    try {
      final details = await _tmdbService.getMediaDetails(
        tmdbId.toString(),
        type.name,
      );
      if (details != null) {
        final item = MediaItem.fromTmdbDetails(details, type);
        // Save to cache (memory and local)
        await saveMediaItem(item);
        return item;
      }
    } catch (e, s) {
      developer.log(
        'Failed to fetch media details ($tmdbId, ${type.name}) from TMDB service',
        name: 'MediaRepository',
        error: e,
        stackTrace: s,
      );
    }

    return null;
  }

  Future<List<MediaItem>> getMediaItems(
    List<({int id, MediaKind type})> requests,
  ) async {
    if (requests.isEmpty) return [];

    try {
      final filters = requests
          .map((r) => (id: r.id, type: r.type.name))
          .toList();
      final localResults = await _db.getMediaItems(filters);

      return localResults.map<MediaItem>(_mapToMediaItem).toList();
    } catch (e, s) {
      developer.log(
        'Failed to fetch batch media items from Drift database',
        name: 'MediaRepository',
        error: e,
        stackTrace: s,
      );
      return [];
    }
  }

  /// Copies the titles in [requests] that the local cache doesn't have yet
  /// from the shared `media_cache` table, so a second device shows their
  /// title and poster. Titles missing there too stay missing.
  /// Throws an [AppFailure].
  Future<void> cacheMissingFromRemote(
    List<({int id, MediaKind type})> requests,
  ) async {
    final local = await _db.getMediaItems(
      requests.map((r) => (id: r.id, type: r.type.name)).toList(),
    );
    final have = {for (final row in local) '${row.mediaType}-${row.tmdbId}'};
    final missing = {
      for (final r in requests)
        if (!have.contains('${r.type.name}-${r.id}')) '${r.type.name}-${r.id}',
    };
    if (missing.isEmpty) return;

    final ids = requests.map((r) => r.id).toSet().toList();
    for (var i = 0; i < ids.length; i += 100) {
      final chunk = ids.sublist(i, i + 100 > ids.length ? ids.length : i + 100);
      final rows = await _supabase
          .from('media_cache')
          .select(
            'tmdb_id, media_type, title_en, title_it, poster_path, '
            'backdrop_path, runtime_minutes, genres, release_date, updated_at',
          )
          .inFilter('tmdb_id', chunk)
          .withAppFailure();
      for (final row in rows) {
        final type = row['media_type'] as String;
        final id = row['tmdb_id'] as int;
        if (!missing.contains('$type-$id')) continue;
        final releaseDate = row['release_date'] as String?;
        final updatedAt = row['updated_at'] as String?;
        await _db.upsertMediaItem(
          CachedMediaItemsCompanion(
            tmdbId: Value(id),
            mediaType: Value(type),
            titleIt: Value(row['title_it'] as String?),
            titleEn: Value(row['title_en'] as String?),
            posterPath: Value(row['poster_path'] as String?),
            backdropPath: Value(row['backdrop_path'] as String?),
            runtimeMinutes: Value(row['runtime_minutes'] as int?),
            genres: Value(
              row['genres'] != null ? jsonEncode(row['genres']) : null,
            ),
            releaseDate: Value(
              releaseDate != null ? DateTime.tryParse(releaseDate) : null,
            ),
            updatedAt: Value(
              (updatedAt != null ? DateTime.tryParse(updatedAt) : null) ??
                  DateTime.now(),
            ),
          ),
        );
      }
    }
  }

  /// Ensures a media item exists in the local cache and remote database.
  Future<void> saveMediaItem(MediaItem item) async {
    final key = '${item.mediaType.name}-${item.tmdbId}';

    // Update memory
    _memoryCache[key] = item;

    // Save to Local Cache (Drift)
    try {
      await _db.upsertMediaItem(
        CachedMediaItemsCompanion(
          tmdbId: Value(item.tmdbId),
          mediaType: Value(item.mediaType.name),
          titleIt: Value(item.titleIt),
          titleEn: Value(item.titleEn),
          posterPath: Value(item.posterPath),
          backdropPath: Value(item.backdropPath),
          runtimeMinutes: Value(item.runtimeMinutes),
          genres: Value(item.genres != null ? jsonEncode(item.genres) : null),
          castMembers: Value(
            item.castMembers != null ? jsonEncode(item.castMembers) : null,
          ),
          releaseDate: Value(item.releaseDate),
          voteAverage: Value(item.voteAverage),
          updatedAt: Value(item.updatedAt),
        ),
      );
    } catch (e, s) {
      developer.log(
        'Failed to upsert media item ($key) into Drift database',
        name: 'MediaRepository',
        error: e,
        stackTrace: s,
      );
    }

    // Save to Remote Cache (Supabase)
    try {
      await _supabase.from('media_cache').upsert({
        'tmdb_id': item.tmdbId,
        'media_type': item.mediaType.name,
        'title_en': item.titleEn,
        'title_it': item.titleIt,
        'poster_path': item.posterPath,
        'backdrop_path': item.backdropPath,
        'runtime_minutes': item.runtimeMinutes,
        'genres': item.genres ?? [],
        'cast_members': item.castMembers ?? [],
        'release_date': item.releaseDate?.toIso8601String().split('T')[0],
        'updated_at': item.updatedAt.toUtc().toIso8601String(),
      }).withAppFailure();
    } catch (e, stackTrace) {
      developer.log(
        'Failed to sync media cache to remote for ${item.tmdbId}',
        name: 'MediaRepository',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Map Drift data to Domain model
  MediaItem _mapToMediaItem(CachedMediaItem data) {
    return MediaItem(
      tmdbId: data.tmdbId,
      mediaType: MediaKind.values.firstWhere(
        (e) => e.name == data.mediaType,
        orElse: () => MediaKind.movie,
      ),
      titleIt: data.titleIt == null || data.titleIt!.trim().isEmpty
          ? null
          : data.titleIt,
      titleEn: data.titleEn == null || data.titleEn!.trim().isEmpty
          ? null
          : data.titleEn,
      posterPath: data.posterPath,
      backdropPath: data.backdropPath,
      runtimeMinutes: data.runtimeMinutes,
      genres: data.genres != null
          ? (jsonDecode(data.genres!) as List).cast<int>()
          : null,
      castMembers: data.castMembers != null
          ? (jsonDecode(data.castMembers!) as List).cast<int>()
          : null,
      releaseDate: data.releaseDate,
      voteAverage: data.voteAverage,
      updatedAt: data.updatedAt,
    );
  }
}
