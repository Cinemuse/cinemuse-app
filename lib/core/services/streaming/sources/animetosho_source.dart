import 'package:cinemuse_app/core/services/streaming/models/stream_search_context.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/streaming/sources/base_source.dart';
import 'package:cinemuse_app/core/services/streaming/ranking/stream_parser.dart';
import 'package:cinemuse_app/core/utils/media_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

class AnimeToshoSource extends BaseSource {
  final Dio _dio;
  static const String _baseUrl = "https://feed.animetosho.org/json";

  @override
  final String name;

  AnimeToshoSource(this._dio, {this.name = 'AnimeTosho'});

  @override
  Set<String> get supportedCategories => {'anime'};

  @override
  Future<List<StreamCandidate>> search(StreamSearchContext context) async {
    // Only search AnimeTosho if it's actually an anime and we have an AniDB ID
    if (!context.isAnime || context.mapping?.anidbId == null) {
      debugPrint('AnimeToshoSource: Skipping search. isAnime: ${context.isAnime}, anidbId: ${context.mapping?.anidbId}');
      return [];
    }

    final anidbId = context.mapping!.anidbId;
    // Treat 0 as invalid (movies get mapped with absEp=0 from fallback)
    final absoluteEpisode = (context.mapping?.absoluteEpisode != null && context.mapping!.absoluteEpisode! > 0)
        ? context.mapping!.absoluteEpisode
        : null;
    
    // We perform two searches in parallel:
    // 1. Specific absolute episode (e.g., "05")
    // 2. Batches/Complete releases
    final List<Future<List<StreamCandidate>>> searchTasks = [];

    // Episode search
    if (absoluteEpisode != null) {
      final epParams = {
        'qx': 1,
        'only_tor': 1,
        'aids': anidbId,
        'q': absoluteEpisode.toString().padLeft(2, '0'),
      };
      searchTasks.add(_fetch(epParams, context, absoluteEpisode));
    } else {
      // General series search if no specific episode
      final seriesParams = {
        'qx': 1,
        'only_tor': 1,
        'aids': anidbId,
      };
      searchTasks.add(_fetch(seriesParams, context, null));
    }

    // Batch search
    final batchParams = {
      'qx': 1,
      'only_tor': 1,
      'aids': anidbId,
      'q': 'batch',
    };
    searchTasks.add(_fetch(batchParams, context, absoluteEpisode));

    // Complete series search (often distinct from "batch")
    final completeParams = {
      'qx': 1,
      'only_tor': 1,
      'aids': anidbId,
      'q': 'complete',
    };
    searchTasks.add(_fetch(completeParams, context, absoluteEpisode));

    try {
      final results = await Future.wait(searchTasks);
      final allCandidates = results.expand((x) => x).toList();
      
      // Deduplicate by infoHash
      final uniqueMap = <String, StreamCandidate>{};
      for (final c in allCandidates) {
        if (!uniqueMap.containsKey(c.infoHash)) {
          uniqueMap[c.infoHash] = c;
        }
      }
      
      return uniqueMap.values.toList();
    } catch (e) {
      debugPrint('AnimeToshoSource: Search failed: $e');
      return [];
    }
  }

  Future<List<StreamCandidate>> _fetch(Map<String, dynamic> params, StreamSearchContext context, int? absoluteEpisode) async {
    try {
      final response = await _dio.get(_baseUrl, queryParameters: params);
      
      if (response.statusCode != 200 || response.data == null) {
        return [];
      }

      final List results = response.data is List ? response.data : [];
      final List<StreamCandidate> candidates = [];

      for (final item in results) {
        final title = item['title'] as String? ?? '';
        final infoHash = item['info_hash'] as String? ?? '';
        final magnet = item['magnet_uri'] as String? ?? '';
        final sizeBytes = item['total_size'] as int? ?? 0;
        final seeds = item['seeders'] as int? ?? 0;

        // Verify episode match using MediaParser
        // This now supports batches via the updated MediaParser.matches
        if (absoluteEpisode != null) {
          if (!MediaParser.matches(
            title,
            targetAbsoluteEpisode: absoluteEpisode,
            targetSeason: context.season,
            targetEpisode: context.episode,
          )) {
            continue; 
          }
        }

        final metadata = StreamParser.parse(title);

        candidates.add(StreamCandidate(
          kind: StreamSourceKind.vod,
          title: title,
          infoHash: infoHash,
          magnet: magnet,
          seeds: seeds,
          provider: name,
          absoluteEpisode: absoluteEpisode,
          metadata: metadata,
          sizeInBytes: sizeBytes,
          resolution: metadata.video.resolution.label,
        ));
      }

      return candidates;
    } catch (e) {
      debugPrint('AnimeToshoSource fetch error: $e');
      return [];
    }
  }
}
