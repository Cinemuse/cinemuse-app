import 'package:cinemuse_app/core/services/streaming/models/media_context.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/streaming/sources/base_source.dart';
import 'package:cinemuse_app/core/services/streaming/ranking/stream_ranker.dart';
import 'package:dio/dio.dart';

class StremioSource implements BaseSource {
  final Dio _dio;
  final String _baseUrl;
  @override
  final String name;

  StremioSource(this._dio, this._baseUrl, {this.name = 'Torrentio'});

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
          final title = (s['title'] ?? "").replaceAll('\n', " ");
          return StreamCandidate(
            title: context.kitsuMapping != null ? " (Kitsu) $title" : title,
            infoHash: s['infoHash'] ?? "",
            magnet: "magnet:?xt=urn:btih:${s['infoHash']}&dn=${Uri.encodeComponent(title)}",
            seeds: s['seeds'] ?? 0,
            provider: name,
            absoluteEpisode: context.kitsuMapping?.absoluteEpisode,
            metadata: StreamRanker.parseMetadata(title),
          );
        }).toList();
      }
    } catch (e) {
      print('StremioSource ($name) fetch failed: $e');
    }
    return [];
  }
}
