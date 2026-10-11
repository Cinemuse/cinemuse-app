import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'dart:convert';
import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cinemuse_app/features/streaming/anime/models/kitsu_mapping.dart';

final kitsuMappingServiceProvider = Provider((ref) {
  return KitsuMappingService(
    ref.read(dioProvider),
    ref.read(appDatabaseProvider),
  );
});

class KitsuMappingService {
  static const String _logTag = 'KitsuMappingService';

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
                AppLogger.debug(
                  _logTag,
                  'TMDB $tmdbId S$season E$episode -> Kitsu $kitsuId (absEp=$result)',
                );
                return KitsuMapping(
                  kitsuId: kitsuId,
                  absoluteEpisode: result,
                  anidbId: mapping.anidbId,
                  anilistId: mapping.anilistId,
                );
              }
            }
          }
        }
      }
    }

    // 3. Handle Folded/Sequential Seasons (The "Overflow" Logic)
    if (type == 'tv' && season != null && episode != null) {
      // Sort candidates by their seasonal index (s1, s2, s3...)
      candidates.sort(
        (a, b) => _getSeasonIndex(a).compareTo(_getSeasonIndex(b)),
      );

      int remainingEpisode = episode;

      for (int i = 0; i < candidates.length; i++) {
        final mapping = candidates[i];
        final Map<String, dynamic> tmdbMap = mapping.mappingsData != null
            ? jsonDecode(mapping.mappingsData!)
            : {};

        // Find the "primary" season key for this mapping (usually only one)
        final String mappingSeasonKey = tmdbMap.keys.firstWhere(
          (k) => k.startsWith('s'),
          orElse: () => '',
        );

        if (mappingSeasonKey.startsWith('s')) {
          final mappingSeasonNum =
              int.tryParse(mappingSeasonKey.substring(1)) ?? 0;

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
            AppLogger.debug(
              _logTag,
              'TMDB $tmdbId S$season E$episode -> Kitsu ${kitsuData.kitsuId} (absEp=$remainingEpisode)',
            );
            return KitsuMapping(
              kitsuId: kitsuData.kitsuId,
              absoluteEpisode: remainingEpisode,
              anidbId: mapping.anidbId,
              anilistId: mapping.anilistId,
            );
          } else {
            remainingEpisode -= count;
          }
        }
      }
    }

    // 4. Fallback. For an episode, only a row that names no season may be
    // guessed: a row of another season (or s0, the specials) would copy the
    // TMDB episode number onto the wrong anime, and rows of this season were
    // already checked above (REV-233). With no row left, the sources search by
    // IMDb ID instead.
    final isEpisode = type == 'tv' && season != null && episode != null;
    final fallback = isEpisode
        ? candidates.where((c) => !_hasSeasonKey(c)).firstOrNull
        : candidates.first;
    if (fallback == null) {
      AppLogger.debug(
        _logTag,
        'TMDB $tmdbId S$season E$episode: no mapping covers this episode',
      );
      return null;
    }

    final kitsuId = await _getKitsuId(fallback.anilistId);
    if (kitsuId != null) {
      final validEpisode = (episode != null && episode > 0) ? episode : null;
      AppLogger.debug(
        _logTag,
        'TMDB $tmdbId (fallback) -> Kitsu $kitsuId (absEp=$validEpisode)',
      );
      return KitsuMapping(
        kitsuId: kitsuId,
        absoluteEpisode: validEpisode,
        anidbId: fallback.anidbId,
        anilistId: fallback.anilistId,
      );
    }

    return null;
  }

  bool _hasSeasonKey(AnimeExternalMapping mapping) {
    if (mapping.mappingsData == null) return false;
    try {
      final Map<String, dynamic> map = jsonDecode(mapping.mappingsData!);
      return map.keys.any((k) => k.startsWith('s'));
    } catch (_) {
      // Unreadable data says nothing about seasons either.
      return false;
    }
  }

  int _getSeasonIndex(AnimeExternalMapping mapping) {
    if (mapping.mappingsData == null) return 0;
    try {
      final Map<String, dynamic> map = jsonDecode(mapping.mappingsData!);
      final key = map.keys.firstWhere(
        (k) => k.startsWith('s'),
        orElse: () => 's0',
      );
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
          if (end != null && episode >= start && episode <= end) {
            return episode - start + 1;
          }
        }
      } else {
        final epVal = int.tryParse(cleanRange);
        if (epVal == episode) return 1;
      }
    } catch (e, s) {
      AppLogger.warn(
        _logTag,
        'Failed to parse episode offset from range "$range" for episode $episode',
        error: e,
        stackTrace: s,
      );
    }
    return null;
  }

  Future<String?> _getKitsuId(int anilistId) async {
    final data = await _getKitsuData(anilistId);
    return data?.kitsuId;
  }

  Future<({int? episodeCount, String kitsuId})?> _getKitsuData(
    int anilistId,
  ) async {
    final cached = await _db.getKitsuMapping(anilistId);
    if (cached != null) {
      return (episodeCount: cached.episodeCount, kitsuId: cached.kitsuId);
    }

    final url =
        'https://kitsu.io/api/edge/mappings?filter[external_id]=$anilistId&filter[external_site]=anilist/anime&include=item';
    try {
      final res = await _dio.get(url);
      if (res.statusCode == 200 &&
          res.data['data'] != null &&
          (res.data['data'] as List).isNotEmpty) {
        final data = res.data['data'][0];
        final String? kitsuId = data['relationships']?['item']?['data']?['id']
            ?.toString();

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
          await _db.upsertKitsuMapping(
            AnimeKitsuMappingsCompanion(
              anilistId: Value(anilistId),
              kitsuId: Value(kitsuId),
              episodeCount: Value(epCount),
            ),
          );
          return (episodeCount: epCount, kitsuId: kitsuId);
        }
      }
    } catch (e) {
      AppLogger.warn(_logTag, 'Failed to get Kitsu data', error: e);
    }
    return null;
  }
}
