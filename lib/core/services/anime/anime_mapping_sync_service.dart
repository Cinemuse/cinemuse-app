import 'dart:convert';
import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:cinemuse_app/core/services/system/batch_manager.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/core/services/anime/kitsu_mapping_service.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final animeMappingSyncServiceProvider = Provider((ref) {
  return AnimeMappingSyncService(
    ref.read(dioProvider),
    ref.read(appDatabaseProvider),
  );
});

class AnimeMappingSyncService {
  final Dio _dio;
  final AppDatabase _db;
  static const String _lastSyncKey = 'last_anime_mapping_sync';
  static const String _mappingUrl = 'https://raw.githubusercontent.com/eliasbenb/PlexAniBridge-Mappings/refs/heads/v2/mappings.json';

  AnimeMappingSyncService(this._dio, this._db);

  /// Checks if a sync is needed and performs it in the background if so.
  Future<void> checkAndSync() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString(_lastSyncKey);
    final lastSync = lastSyncStr != null ? DateTime.tryParse(lastSyncStr) : null;
    
    // Check if we have data at all
    final count = await _db.getAnimeExternalMappingsCount();
    final isEmpty = count == 0;

    if (isEmpty || lastSync == null || DateTime.now().difference(lastSync).inHours > 24) {
      if (isEmpty) {
        print('AnimeMappingSyncService: Mapping table is empty, forcing sync...');
      } else {
        print('AnimeMappingSyncService: Starting daily sync...');
      }
      
      await _sync();
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
      print('AnimeMappingSyncService: Sync completed.');
    } else {
      print('AnimeMappingSyncService: Mapping is up to date (last sync: $lastSync, count: $count).');
    }
  }

  Future<void> _sync() async {
    try {
      final response = await _dio.get(_mappingUrl);
      if (response.statusCode != 200) throw Exception('Failed to download mappings');

      final Map<String, dynamic> data = response.data is String 
          ? jsonDecode(response.data) 
          : response.data;
      
      final List<AnimeExternalMappingsCompanion> companions = [];

      data.forEach((anilistIdStr, value) {
        final anilistId = int.tryParse(anilistIdStr);
        if (anilistId == null) return;

        final map = value as Map<String, dynamic>;
        
        // Extract IDs
        final tmdbShowId = _extractInt(map['tmdb_show_id']);
        final tmdbMovieId = _extractInt(map['tmdb_movie_id']);
        final tvdbId = _extractInt(map['tvdb_id']);
        
        // Extract mappings (pick tmdb first, fallback to tvdb)
        final mappings = map['tmdb_mappings'] ?? map['tvdb_mappings'];
        final mappingsJson = mappings != null ? jsonEncode(mappings) : null;

        if (tmdbShowId != null || tmdbMovieId != null || tvdbId != null) {
          companions.add(AnimeExternalMappingsCompanion(
            anilistId: Value(anilistId),
            tmdbShowId: Value(tmdbShowId),
            tmdbMovieId: Value(tmdbMovieId),
            tvdbId: Value(tvdbId),
            mappingsData: Value(mappingsJson),
          ));
        }
      });

      if (companions.isNotEmpty) {
        await _db.replaceAnimeExternalMappings(companions);
      }
    } catch (e) {
      print('AnimeMappingSyncService: Sync failed: $e');
    }
  }

  int? _extractInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is List && value.isNotEmpty) return _extractInt(value[0]);
    return null;
  }
}
