import 'package:flutter/foundation.dart';
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
  final String? _queryParams;
  
  @override
  final String name;
  
  @override
  final Set<String> supportedCategories;

  StremioSource(
    Dio dio, 
    String baseUrl, 
    {
      this.name = 'Torrentio', 
      this.supportedCategories = const {'movie', 'tv', 'anime'},
      String? queryParams,
    }
  ) : _dio = dio, 
      _baseUrl = baseUrl,
      _queryParams = queryParams;

  @override
  Future<List<StreamCandidate>> search(StreamSearchContext context) async {
    final params = _resolveRequestParams(context);
    final type = params.type;
    final queryId = params.queryId;
    
    final resourcePath = "/stream/$type/$queryId.json";
    final url = UrlUtils.unencodeStremioUrl(
      _queryParams != null ? "$_baseUrl$resourcePath?$_queryParams" : "$_baseUrl$resourcePath"
    );

    try {
      debugPrint('StremioSource ($name): Fetching: $url');
      
      final res = await _dio.get(url, options: Options(receiveTimeout: const Duration(seconds: 25)));
      
      if (res.statusCode == 200 && res.data['streams'] != null) {
        final streamsData = res.data['streams'] as List;
        debugPrint('StremioSource ($name): Found ${streamsData.length} raw streams');
        
        return streamsData.map((s) {
          final rawTitle = (s['title'] ?? s['description'] ?? "").replaceAll('\n', " ");
          final nameStr = s['name'] != null ? "[${s['name']}] " : "";
          final title = "$nameStr$rawTitle";
          
          final infoHash = s['infoHash'] ?? "";
          final streamUrl = s['url'];
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
            url: streamUrl,
          );
        }).toList();
      } else {
        debugPrint('StremioSource ($name): Unexpected response: ${res.statusCode}');
      }
    } on DioException catch (e) {
      debugPrint('StremioSource ($name) fetch failed: ${e.message} (URL: $url)');
    } catch (e) {
      debugPrint('StremioSource ($name) unexpected error: $e');
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
    final baseId = context.imdbId ?? context.tmdbId;
    final isEpisodeQuery = type == 'series' && context.season != null && context.episode != null;
    
    return (
      type: type, 
      queryId: isEpisodeQuery ? "$baseId:${context.season}:${context.episode}" : baseId,
    );
  }
}
