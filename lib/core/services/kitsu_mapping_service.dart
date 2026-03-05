import 'dart:convert';
import 'package:cinemuse_app/core/data/database.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class KitsuMapping {
  final String kitsuId;
  final int? absoluteEpisode;

  KitsuMapping({required this.kitsuId, this.absoluteEpisode});
}

final kitsuMappingServiceProvider = Provider((ref) {
  return KitsuMappingService(
    Dio(),
    ref.read(appDatabaseProvider),
  );
});

class KitsuMappingService {
  final Dio _dio;
  final AppDatabase _db;

  KitsuMappingService(this._dio, this._db);

  /// Resolves a TMDB ID, season, and episode to a Kitsu ID and absolute episode.
  Future<KitsuMapping?> getMapping({
    required int tmdbId,
    required String type,
    int? season,
    int? episode,
  }) async {
    print('KitsuMappingService: Resolving mapping for TMDB $tmdbId, $type, S$season E$episode');
    
    // 1. Get External Mapping Candidates from Local DB
    List<AnimeExternalMapping> candidates;
    if (type == 'movie') {
      candidates = await _db.getAnimeMappingsByTmdbMovie(tmdbId);
    } else {
      candidates = await _db.getAnimeMappingsByTmdbShow(tmdbId);
    }

    if (candidates.isEmpty) {
      print('KitsuMappingService: No external mappings found in local DB for TMDB $tmdbId');
      return null;
    }

    print('KitsuMappingService: Found ${candidates.length} mapping candidates');

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
               print('KitsuMappingService: Found specific range match: $range -> Episode $result for AniList ${mapping.anilistId}');
               final kitsuId = await _getKitsuId(mapping.anilistId);
               if (kitsuId != null) return KitsuMapping(kitsuId: kitsuId, absoluteEpisode: result);
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
      print('KitsuMappingService: Entering overflow logic for S$season E$episode');

      for (int i = 0; i < candidates.length; i++) {
        final mapping = candidates[i];
        final Map<String, dynamic> tmdbMap = mapping.mappingsData != null ? jsonDecode(mapping.mappingsData!) : {};
        
        // Find the "primary" season key for this mapping (usually only one)
        final String? mappingSeasonKey = tmdbMap.keys.firstWhere((k) => k.startsWith('s'), orElse: () => '');
        
        if (mappingSeasonKey != null && mappingSeasonKey.startsWith('s')) {
          final mappingSeasonNum = int.tryParse(mappingSeasonKey.substring(1)) ?? 0;
          
          // If this candidate maps to a season < our target season, skip it (it's in the past)
          if (mappingSeasonNum < season) {
            print('KitsuMappingService: Skipping AniList ${mapping.anilistId} (Season $mappingSeasonNum < $season)');
            continue;
          }

          // Resolve Kitsu metadata (ID and Episode Count)
          final kitsuData = await _getKitsuData(mapping.anilistId);
          if (kitsuData == null) {
             print('KitsuMappingService: Failed to get Kitsu data for AniList ${mapping.anilistId}, skipping');
             continue;
          }

          final count = kitsuData.episodeCount ?? 999;
          print('KitsuMappingService: Checking candidate AniList ${mapping.anilistId} (Kitsu ${kitsuData.kitsuId}): episodeCount=$count, remaining=$remainingEpisode');

          if (remainingEpisode <= count) {
            print('KitsuMappingService: Successfully mapped to Kitsu ${kitsuData.kitsuId} Episode $remainingEpisode');
            return KitsuMapping(kitsuId: kitsuData.kitsuId, absoluteEpisode: remainingEpisode);
          } else {
            print('KitsuMappingService: Episode $remainingEpisode overflows Kitsu ${kitsuData.kitsuId} (max $count)');
            remainingEpisode -= count;
          }
        }
      }
    }

    // Fallback: Just return the first available mapping
    print('KitsuMappingService: Overflow failed, falling back to first candidate');
    final targetAnilistId = candidates.first.anilistId;
    final kitsuId = await _getKitsuId(targetAnilistId);
    if (kitsuId != null) {
      return KitsuMapping(kitsuId: kitsuId, absoluteEpisode: episode);
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

  Future<({String kitsuId, int? episodeCount})?> _getKitsuData(int anilistId) async {
    final cached = await _db.getKitsuMapping(anilistId);
    if (cached != null) {
      return (kitsuId: cached.kitsuId, episodeCount: cached.episodeCount);
    }

    final url = 'https://kitsu.io/api/edge/mappings?filter[external_id]=$anilistId&filter[external_site]=anilist/anime&include=item';
    try {
      final res = await _dio.get(url);
      if (res.statusCode == 200 && res.data['data'] != null && (res.data['data'] as List).isNotEmpty) {
        final data = res.data['data'][0];
        final kitsuId = data['relationships']?['item']?['data']?['id']?.toString();
        
        int? epCount;
        final included = res.data['included'] as List?;
        if (included != null && included.isNotEmpty) {
          // Look for the anime object in included to get episodeCount
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
          return (kitsuId: kitsuId, episodeCount: epCount);
        }
      }
    } catch (e) {
      print('KitsuMappingService: Failed to fetch Kitsu data for AniList $anilistId: $e');
    }
    return null;
  }
}
