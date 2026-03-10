import 'package:cinemuse_app/core/services/streaming/models/stream_search_context.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/streaming/sources/base_source.dart';
import 'package:cinemuse_app/core/services/streaming/ranking/stream_ranker.dart';
import 'package:cinemuse_app/core/utils/media_parser.dart';
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
      print('AnimeToshoSource: Skipping search. isAnime: ${context.isAnime}, anidbId: ${context.mapping?.anidbId}');
      return [];
    }

    final anidbId = context.mapping!.anidbId;
    final absoluteEpisode = context.mapping?.absoluteEpisode;
    
    // Construct search query
    // aids: filters by Series
    // q: filters by episode (e.g., "05")
    final Map<String, dynamic> params = {
      'qx': 1,
      'only_tor': 1,
      'aids': anidbId,
    };

    if (absoluteEpisode != null) {
      params['q'] = absoluteEpisode.toString().padLeft(2, '0');
    }

    try {
      final logParams = params.map((key, value) => MapEntry(key, value.toString()));
      final url = "$_baseUrl?${Uri(queryParameters: logParams).query}";
      print('AnimeToshoSource: Fetching: $url');
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
        if (absoluteEpisode != null) {
          if (!MediaParser.matches(
            title,
            targetAbsoluteEpisode: absoluteEpisode,
            targetSeason: context.season,
            targetEpisode: context.episode,
          )) {
            continue; // Skip if it doesn't match our target episode
          }
        }

        candidates.add(StreamCandidate(
          title: title,
          infoHash: infoHash,
          magnet: magnet,
          seeds: seeds,
          provider: name,
          absoluteEpisode: absoluteEpisode,
          metadata: {
            ...StreamRanker.parseMetadata(title),
            'sizeBytes': sizeBytes,
          },
        ));
      }

      return candidates;
    } catch (e) {
      print('AnimeToshoSource: Search failed: $e');
      return [];
    }
  }
}
