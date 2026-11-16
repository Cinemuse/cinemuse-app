import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'dart:convert';
import 'dart:isolate';
import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final animeMappingSyncServiceProvider = Provider((ref) {
  final client = ref.read(supabaseClientProvider);
  return AnimeMappingSyncService(
    ref.read(dioProvider),
    ref.read(appDatabaseProvider),
    url: '${SupabaseConfig.url}/functions/v1/anime-mapping',
    apiKey: SupabaseConfig.publishableKey,
    accessToken: () => client.auth.currentSession?.accessToken,
  );
});

/// Keeps the anime mapping (anime ids → TMDB seasons and episodes) in the
/// local database, downloaded once a day from the `anime-mapping` edge
/// function. The last good list stays when a download fails.
class AnimeMappingSyncService {
  static const String _logTag = 'AnimeMappingSyncService';

  final Dio _dio;
  final AppDatabase _db;
  final String _url;
  final String _apiKey;
  final String? Function() _accessToken;

  // A new key, so the switch to the server's list syncs at once (REV-316).
  static const String _lastSyncKey = 'last_anime_mapping_sync_server';
  static const List<String> _oldLastSyncKeys = [
    'last_anime_mapping_sync',
    'last_anime_mapping_sync_fribb',
  ];

  AnimeMappingSyncService(
    this._dio,
    this._db, {
    required String url,
    required String apiKey,
    required String? Function() accessToken,
  }) : _url = url,
       _apiKey = apiKey,
       _accessToken = accessToken;

  /// Checks if a sync is needed and performs it in the background if so.
  Future<void> checkAndSync() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _oldLastSyncKeys) {
      await prefs.remove(key);
    }
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
    // Only signed-in users may read the list.
    final token = _accessToken();
    if (token == null) {
      AppLogger.debug(_logTag, 'Not signed in, sync skipped');
      return false;
    }
    try {
      // Plain text, so the JSON is decoded in the isolate below, not here.
      final response = await _dio.get<String>(
        _url,
        options: Options(
          responseType: ResponseType.plain,
          headers: {'apikey': _apiKey, 'Authorization': 'Bearer $token'},
        ),
      );
      final body = response.data;
      if (response.statusCode != 200 || body == null) {
        AppLogger.warn(_logTag, 'Sync failed: status ${response.statusCode}');
        return false;
      }

      // Thousands of rows: decoding them on the UI isolate made the app
      // stutter right after start.
      final companions = await Isolate.run(() => parseRows(body));
      if (companions.isEmpty) {
        AppLogger.warn(_logTag, 'Sync failed: the mapping list is empty');
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

  /// Turns the function's answer (`{"rows": [...]}`) into database rows,
  /// each anime's exact TMDB episodes kept as the server sends them
  /// (`tmdb_episodes`). Static, so it can run in another isolate.
  @visibleForTesting
  static List<AnimeExternalMappingsCompanion> parseRows(String body) {
    final data = jsonDecode(body);
    final rows = data is Map<String, dynamic> ? data['rows'] : null;
    if (rows is! List) return const [];

    return [
      for (final row in rows)
        if (row is Map<String, dynamic> && row['anilist_id'] is int)
          AnimeExternalMappingsCompanion(
            anilistId: Value(row['anilist_id'] as int),
            anidbId: Value(_intOrNull(row['anidb_id'])),
            kitsuId: Value(_intOrNull(row['kitsu_id'])),
            tmdbShowId: Value(_intOrNull(row['tmdb_show_id'])),
            tmdbMovieId: Value(_intOrNull(row['tmdb_movie_id'])),
            tmdbEpisodes: Value(
              row['tmdb_episodes'] is List
                  ? jsonEncode(row['tmdb_episodes'])
                  : null,
            ),
          ),
    ];
  }

  static int? _intOrNull(dynamic value) => value is int ? value : null;
}
