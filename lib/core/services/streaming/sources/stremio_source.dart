import 'package:cinemuse_app/core/utils/url_utils.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_search_context.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/streaming/sources/base_source.dart';
import 'package:cinemuse_app/core/services/streaming/ranking/stream_ranker.dart';
import 'package:cinemuse_app/core/services/streaming/ranking/stream_parser.dart';
import 'package:dio/dio.dart';

class StremioSource implements BaseSource {
  final Dio _dio;
  final String _baseUrl;
  
  @override
  final String name;
  
  @override
  final Set<String> supportedCategories;

  StremioSource(
    Dio dio, 
    String baseUrl, 
    {
      this.name = 'Torrentio', 
      this.supportedCategories = const {'movie', 'tv', 'anime'}
    }
  ) : _dio = dio, _baseUrl = UrlUtils.cleanStremioBaseUrl(baseUrl);

  @override
  Future<List<StreamCandidate>> search(StreamSearchContext context) async {
    try {
      final params = _resolveRequestParams(context);
      final type = params.type;
      final queryId = params.queryId;

      final url = "$_baseUrl/stream/$type/$queryId.json";
      print('StremioSource ($name): Fetching: $url');
      
      final res = await _dio.get(url, options: Options(receiveTimeout: const Duration(seconds: 25)));
      
      if (res.statusCode == 200 && res.data['streams'] != null) {
        final streamsData = res.data['streams'] as List;
        return streamsData.map((s) {
          final rawTitle = (s['title'] ?? s['description'] ?? "").replaceAll('\n', " ");
          final name = s['name'] != null ? "[${s['name']}] " : "";
          final title = "$name$rawTitle";
          
          final infoHash = s['infoHash'] ?? "";
          final url = s['url'];
          final metadata = StreamParser.parse(title);

          return StreamCandidate(
            title: context.mapping != null ? " (Kitsu) $title" : title,
            infoHash: infoHash,
            magnet: infoHash.isNotEmpty 
                ? "magnet:?xt=urn:btih:$infoHash&dn=${Uri.encodeComponent(title)}"
                : "",
            seeds: s['seeds'] ?? 0,
            provider: this.name,
            absoluteEpisode: context.mapping?.absoluteEpisode,
            metadata: metadata,
            resolution: metadata.video.resolution.label,
            url: url,
          );
        }).toList();
      }
    } catch (e) {
      print('StremioSource ($name) fetch failed: $e');
    }
    return [];
  }

  /// Resolves the Stremio-specific type and query ID based on context.
  ({String type, String queryId}) _resolveRequestParams(StreamSearchContext context) {
    if (context.mapping case final mapping?) {
      final type = context.type == 'movie' ? 'movie' : 'anime';
      final ep = mapping.absoluteEpisode ?? 1;
      final id = type == 'anime' ? "kitsu:${mapping.kitsuId}:$ep" : "kitsu:${mapping.kitsuId}";
      return (type: type, queryId: id);
    }

    final type = context.type == 'tv' ? 'series' : context.type;
    final baseId = context.strmiomdbId ?? context.imdbId ?? context.tmdbId;
    final isEpisodeQuery = type == 'series' && context.season != null && context.episode != null;
    
    return (
      type: type, 
      queryId: isEpisodeQuery ? "$baseId:${context.season}:${context.episode}" : baseId,
    );
  }
}
