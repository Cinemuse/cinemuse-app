import 'package:cinemuse_app/core/utils/url_utils.dart';
import 'package:cinemuse_app/core/services/streaming/models/media_context.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/streaming/sources/base_source.dart';
import 'package:cinemuse_app/core/services/streaming/ranking/stream_ranker.dart';
import 'package:dio/dio.dart';

class StremioSource implements BaseSource {
  final Dio _dio;
  String _baseUrl;
  @override
  final String name;

  StremioSource(this._dio, String baseUrl, {this.name = 'Torrentio'}) : _baseUrl = UrlUtils.cleanStremioBaseUrl(baseUrl);

  @override
  Future<List<StreamCandidate>> search(MediaContext context) async {
    try {
      String queryId;
      String type;

      if (context.kitsuMapping != null) {
        type = context.type == 'movie' ? 'movie' : 'anime';
        final ep = context.kitsuMapping!.absoluteEpisode ?? 1;
        queryId = type == 'anime' ? "kitsu:${context.kitsuMapping!.kitsuId}:$ep" : "kitsu:${context.kitsuMapping!.kitsuId}";
      } else {
        type = context.type == 'tv' ? 'series' : context.type;
        queryId = context.strmiomdbId ?? context.tmdbId;
      }

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

          return StreamCandidate(
            title: context.kitsuMapping != null ? " (Kitsu) $title" : title,
            infoHash: infoHash,
            magnet: infoHash.isNotEmpty 
                ? "magnet:?xt=urn:btih:$infoHash&dn=${Uri.encodeComponent(title)}"
                : "",
            seeds: s['seeds'] ?? 0,
            provider: this.name,
            absoluteEpisode: context.kitsuMapping?.absoluteEpisode,
            metadata: StreamRanker.parseMetadata(title),
            url: url,
          );
        }).toList();
      }
    } catch (e) {
      print('StremioSource ($name) fetch failed: $e');
    }
    return [];
  }
}
