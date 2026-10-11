import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'dart:convert';
import 'dart:isolate';
import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final animeMappingSyncServiceProvider = Provider((ref) {
  return AnimeMappingSyncService(
    ref.read(dioProvider),
    ref.read(appDatabaseProvider),
  );
});

class AnimeMappingSyncService {
  static const String _logTag = 'AnimeMappingSyncService';

  final Dio _dio;
  final AppDatabase _db;
  static const String _lastSyncKey = 'last_anime_mapping_sync';
  static const String _mappingUrl =
      'https://raw.githubusercontent.com/eliasbenb/PlexAniBridge-Mappings/refs/heads/v2/mappings.json';

  AnimeMappingSyncService(this._dio, this._db);

  /// Checks if a sync is needed and performs it in the background if so.
  Future<void> checkAndSync() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString(_lastSyncKey);
    final lastSync = lastSyncStr != null
        ? DateTime.tryParse(lastSyncStr)
        : null;

    final count = await _db.getAnimeExternalMappingsCount();
    final isEmpty = count == 0;

    if (isEmpty ||
        lastSync == null ||
        DateTime.now().difference(lastSync).inHours > 24) {
      if (isEmpty) {
        AppLogger.debug(_logTag, 'Mapping table is empty, forcing sync...');
      } else {
        AppLogger.debug(_logTag, 'Starting daily sync...');
      }

      // Save the time only after a good sync: a failed one is retried on
      // the next start instead of 24 h later (REV-34).
      if (await _sync()) {
        await prefs.setString(
          _lastSyncKey,
          DateTime.now().toUtc().toIso8601String(),
        );
        AppLogger.debug(_logTag, 'Sync completed.');
      }
    } else {
      AppLogger.debug(
        _logTag,
        'Mapping is up to date (last sync: $lastSync, count: $count).',
      );
    }
  }

  /// Downloads and stores the mappings. Returns whether it worked.
  Future<bool> _sync() async {
    try {
      // Plain text, so the JSON is decoded in the isolate below, not here.
      final response = await _dio.get<String>(
        _mappingUrl,
        options: Options(responseType: ResponseType.plain),
      );
      final body = response.data;
      if (response.statusCode != 200 || body == null) {
        AppLogger.warn(_logTag, 'Sync failed: status ${response.statusCode}');
        return false;
      }

      // Thousands of entries: decoding them on the UI isolate made the app
      // stutter right after start.
      final companions = await Isolate.run(() => parseMappings(body));
      if (companions.isEmpty) {
        AppLogger.warn(_logTag, 'Sync failed: the mappings file is empty');
        return false;
      }

      await _db.replaceAnimeExternalMappings(companions);
      return true;
    } catch (e) {
      // A background job: the old mappings stay usable until the next try.
      AppLogger.warn(_logTag, 'Sync failed', error: e);
      return false;
    }
  }

  /// Turns the mappings file into database rows. Static, so it can run in
  /// another isolate.
  @visibleForTesting
  static List<AnimeExternalMappingsCompanion> parseMappings(String body) {
    final data = jsonDecode(body) as Map<String, dynamic>;
    final List<AnimeExternalMappingsCompanion> companions = [];

    data.forEach((anilistIdStr, value) {
      final anilistId = int.tryParse(anilistIdStr);
      if (anilistId == null || value is! Map<String, dynamic>) return;

      // Extract IDs
      final anidbId = _extractInt(value['anidb_id']);
      final tmdbShowId = _extractInt(value['tmdb_show_id']);
      final tmdbMovieId = _extractInt(value['tmdb_movie_id']);
      final tvdbId = _extractInt(value['tvdb_id']);

      // Extract mappings (pick tmdb first, fallback to tvdb)
      final mappings = value['tmdb_mappings'] ?? value['tvdb_mappings'];
      final mappingsJson = mappings != null ? jsonEncode(mappings) : null;

      if (tmdbShowId != null || tmdbMovieId != null || tvdbId != null) {
        companions.add(
          AnimeExternalMappingsCompanion(
            anilistId: Value(anilistId),
            anidbId: Value(anidbId),
            tmdbShowId: Value(tmdbShowId),
            tmdbMovieId: Value(tmdbMovieId),
            tvdbId: Value(tvdbId),
            mappingsData: Value(mappingsJson),
          ),
        );
      }
    });

    return companions;
  }

  static int? _extractInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is List && value.isNotEmpty) return _extractInt(value[0]);
    return null;
  }
}
