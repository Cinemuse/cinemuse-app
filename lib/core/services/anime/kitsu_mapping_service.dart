import 'dart:convert';
import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:cinemuse_app/core/services/system/smart_cache.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class KitsuMapping {
  final String kitsuId;
  final int? absoluteEpisode;
  final int? anidbId;

  KitsuMapping({required this.kitsuId, this.absoluteEpisode, this.anidbId});
}

/// Represents a resolved AnimeUnity entry parsed from the Stremio mapping API.
class AnimeUnityEntry {
  /// The numeric AnimeUnity anime ID (e.g. 12 from `/anime/12-one-piece`).
  final int id;

  /// The full path from the mapping (e.g. `/anime/12-one-piece`).
  final String path;

  AnimeUnityEntry({required this.id, required this.path});
}

final kitsuMappingServiceProvider = Provider((ref) {
  return KitsuMappingService(
    ref.read(dioProvider),
    ref.read(appDatabaseProvider),
  );
});

class KitsuMappingService {
  static const _stremioMappingBaseUrl = 'https://animemapping.stremio.dpdns.org/kitsu';

  final Dio _dio;
  final AppDatabase _db;
  final Map<String, List<AnimeUnityEntry>> _animeUnityCache = {};

  KitsuMappingService(this._dio, this._db);

  /// Resolves a TMDB ID, season, and episode to a Kitsu ID and absolute episode.
  Future<KitsuMapping?> getMapping({
    required int tmdbId,
    required String type,
    int? season,
    int? episode,
  }) async {

    
    // 1. Get External Mapping Candidates from Local DB
    List<AnimeExternalMapping> candidates;
    if (type == 'movie') {
      candidates = await _db.getAnimeMappingsByTmdbMovie(tmdbId);
    } else {
      candidates = await _db.getAnimeMappingsByTmdbShow(tmdbId);
    }

    if (candidates.isEmpty) {

      return null;
    }



    // 2. Prioritize Specific Range Mappings
    if (type == 'tv' && season != null && episode != null) {
      final seasonKey = 's$season';
      for (final mapping in candidates) {
        if (mapping.mappingsData == null) continue;
        final Map<String, dynamic> tmdbMap = jsonDecode(mapping.mappingsData!);
        if (tmdbMap.containsKey(seasonKey)) {
          final String range = tmdbMap[seasonKey];
          if (range.isNotEmpty) {
             final result = _tryMatchRange(range, episode);
             if (result != null) {
               final kitsuId = await _getKitsuId(mapping.anilistId);
               if (kitsuId != null) {
                 debugPrint('[KitsuMapping] TMDB $tmdbId S$season E$episode -> Kitsu $kitsuId (absEp=$result)');
                 return KitsuMapping(kitsuId: kitsuId, absoluteEpisode: result, anidbId: mapping.anidbId);
               }
             }
          }
        }
      }
    }

    // 3. Handle Folded/Sequential Seasons (The "Overflow" Logic)
    if (type == 'tv' && season != null && episode != null) {
      // Sort candidates by their seasonal index (s1, s2, s3...)
      candidates.sort((a, b) => _getSeasonIndex(a).compareTo(_getSeasonIndex(b)));

      int remainingEpisode = episode;


      for (int i = 0; i < candidates.length; i++) {
        final mapping = candidates[i];
        final Map<String, dynamic> tmdbMap = mapping.mappingsData != null ? jsonDecode(mapping.mappingsData!) : {};
        
        // Find the "primary" season key for this mapping (usually only one)
        final String? mappingSeasonKey = tmdbMap.keys.firstWhere((k) => k.startsWith('s'), orElse: () => '');
        
        if (mappingSeasonKey != null && mappingSeasonKey.startsWith('s')) {
          final mappingSeasonNum = int.tryParse(mappingSeasonKey.substring(1)) ?? 0;
          
          // If this candidate maps to a season < our target season, skip it (it's in the past)
          if (mappingSeasonNum < season) {

            continue;
          }

          // Resolve Kitsu metadata (ID and Episode Count)
          final kitsuData = await _getKitsuData(mapping.anilistId);
          if (kitsuData == null) {
             continue;
          }

          final count = kitsuData.episodeCount ?? 999;


          if (remainingEpisode <= count) {
            debugPrint('[KitsuMapping] TMDB $tmdbId S$season E$episode -> Kitsu ${kitsuData.kitsuId} (absEp=$remainingEpisode)');
            return KitsuMapping(kitsuId: kitsuData.kitsuId, absoluteEpisode: remainingEpisode, anidbId: mapping.anidbId);
          } else {

            remainingEpisode -= count;
          }
        }
      }
    }

    // Fallback: Just return the first available mapping

    final targetAnilistId = candidates.first.anilistId;
    final kitsuId = await _getKitsuId(targetAnilistId);
    if (kitsuId != null) {
      final validEpisode = (episode != null && episode > 0) ? episode : null;
      debugPrint('[KitsuMapping] TMDB $tmdbId (fallback) -> Kitsu $kitsuId (absEp=$validEpisode)');
      return KitsuMapping(kitsuId: kitsuId, absoluteEpisode: validEpisode, anidbId: candidates.first.anidbId);
    }

    return null;
  }

  int _getSeasonIndex(AnimeExternalMapping mapping) {
    if (mapping.mappingsData == null) return 0;
    try {
      final Map<String, dynamic> map = jsonDecode(mapping.mappingsData!);
      final key = map.keys.firstWhere((k) => k.startsWith('s'), orElse: () => 's0');
      return int.tryParse(key.substring(1)) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  int? _tryMatchRange(String range, int episode) {
    try {
      final cleanRange = range.replaceAll('e', '').split(',')[0].split('|')[0];
      if (cleanRange.contains('-')) {
        final parts = cleanRange.split('-');
        final start = int.tryParse(parts[0]) ?? 1;
        if (parts.length == 1 || parts[1].isEmpty) {
          if (episode >= start) return episode - start + 1;
        } else {
          final end = int.tryParse(parts[1]);
          if (end != null && episode >= start && episode <= end) return episode - start + 1;
        }
      } else {
        final epVal = int.tryParse(cleanRange);
        if (epVal == episode) return 1;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _getKitsuId(int anilistId) async {
    final data = await _getKitsuData(anilistId);
    return data?.kitsuId;
  }

  Future<({int? episodeCount, String kitsuId})?> _getKitsuData(int anilistId) async {
    final cached = await _db.getKitsuMapping(anilistId);
    if (cached != null) {
      return (episodeCount: cached.episodeCount, kitsuId: cached.kitsuId);
    }

    final url = 'https://kitsu.io/api/edge/mappings?filter[external_id]=$anilistId&filter[external_site]=anilist/anime&include=item';
    try {
      final res = await _dio.get(url);
      if (res.statusCode == 200 && res.data['data'] != null && (res.data['data'] as List).isNotEmpty) {
        final data = res.data['data'][0];
        final String? kitsuId = data['relationships']?['item']?['data']?['id']?.toString();
        
        int? epCount;
        final included = res.data['included'] as List?;
        if (included != null && included.isNotEmpty) {
          for (var item in included) {
            if (item['type'] == 'anime') {
               epCount = item['attributes']?['episodeCount'];
               break;
            }
          }
        }

        if (kitsuId != null) {
          await _db.upsertKitsuMapping(AnimeKitsuMappingsCompanion(
            anilistId: Value(anilistId),
            kitsuId: Value(kitsuId),
            episodeCount: Value(epCount),
          ));
          return (episodeCount: epCount, kitsuId: kitsuId);
        }
      }
    } catch (e) {

    }
    return null;
  }

  /// Resolves a Kitsu ID to a list of [AnimeUnityEntry] using the Stremio mapping API.
  /// Returns an empty list if the mapping is unavailable or parsing fails.
  Future<List<AnimeUnityEntry>> getAnimeUnityIds(String kitsuId) async {
    final cached = _animeUnityCache[kitsuId];
    if (cached != null) return cached;

    try {
      final res = await _dio.get('$_stremioMappingBaseUrl/$kitsuId');
      if (res.statusCode != 200 || res.data == null) return [];

      final entries = _parseAnimeUnityPaths(res.data);
      _animeUnityCache[kitsuId] = entries;
      debugPrint('[KitsuMapping] Kitsu $kitsuId -> ${entries.length} AnimeUnity entries');
      return entries;
    } catch (e) {
      debugPrint('[KitsuMapping] AnimeUnity mapping failed for Kitsu $kitsuId: $e');
      return [];
    }
  }

  /// Parses AnimeUnity paths from the Stremio mapping API response.
  /// Expected format: `mappings.animeunity = ["/anime/12-one-piece", ...]`
  List<AnimeUnityEntry> _parseAnimeUnityPaths(Map<String, dynamic> data) {
    final paths = data['mappings']?['animeunity'] as List?;
    if (paths == null) return [];

    final results = <AnimeUnityEntry>[];
    final idPattern = RegExp(r'/anime/(\d+)');

    for (final raw in paths) {
      final path = raw.toString();
      final match = idPattern.firstMatch(path);
      if (match == null) continue;

      final id = int.tryParse(match.group(1)!);
      if (id != null) {
        results.add(AnimeUnityEntry(id: id, path: path));
      }
    }
    return results;
  }
}
