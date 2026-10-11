import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:cinemuse_app/core/utils/url_utils.dart';
import 'package:cinemuse_app/features/streaming/models/stream_search_context.dart';
import 'package:cinemuse_app/features/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/features/streaming/sources/base_source.dart';
import 'package:cinemuse_app/features/streaming/ranking/stream_parser.dart';
import 'package:dio/dio.dart';

class StremioSource implements BaseSource {
  static const String _logTag = 'StremioSource';

  // Torrentio puts the seeder count in the title ("👤 123") instead of `seeds`.
  static final _seedersPattern = RegExp(r'👤\s*(\d+)');

  /// Reads the seeder count from a Torrentio-style title, or 0 if it has none.
  @visibleForTesting
  static int seedersFromTitle(String title) {
    final match = _seedersPattern.firstMatch(title);
    return match == null ? 0 : int.parse(match.group(1)!);
  }

  final Dio _dio;
  final String _baseUrl;
  final String? _queryParams;

  @override
  final String name;

  @override
  final Set<String> supportedCategories;

  StremioSource(
    Dio dio,
    String baseUrl, {
    this.name = 'Torrentio',
    this.supportedCategories = const {'movie', 'tv', 'anime'},
    String? queryParams,
  }) : _dio = dio,
       _baseUrl = baseUrl,
       _queryParams = queryParams;

  @override
  Future<List<StreamCandidate>> search(StreamSearchContext context) async {
    final params = _resolveRequestParams(context);
    final type = params.type;
    final queryId = params.queryId;

    final resourcePath = "/stream/$type/$queryId.json";
    final url = UrlUtils.unencodeStremioUrl(
      _queryParams != null
          ? "$_baseUrl$resourcePath?$_queryParams"
          : "$_baseUrl$resourcePath",
    );

    try {
      // Never log `url`: add-on configs carry API keys in the path (SEC-06).
      AppLogger.debug(_logTag, '$name: fetching $type $queryId');

      final res = await _dio.get(
        url,
        options: Options(receiveTimeout: const Duration(seconds: 25)),
      );

      if (res.statusCode == 200 && res.data['streams'] != null) {
        final streamsData = res.data['streams'] as List;
        AppLogger.debug(
          _logTag,
          '$name: found ${streamsData.length} raw streams',
        );

        return streamsData.map((s) {
          final rawTitle = (s['title'] ?? s['description'] ?? "").replaceAll(
            '\n',
            " ",
          );
          final nameStr = s['name'] != null ? "[${s['name']}] " : "";
          final title = "$nameStr$rawTitle";

          final infoHash = s['infoHash'] ?? "";
          final streamUrl = s['url'];
          final metadata = StreamParser.parse(title);

          final Map<String, String>? headers =
              (s['behaviorHints']?['headers'] as Map?)?.map(
                (k, v) => MapEntry(k.toString(), v.toString()),
              );

          return StreamCandidate(
            kind: StreamSourceKind.vod,
            title: title,
            infoHash: infoHash,
            magnet: infoHash.isNotEmpty
                ? "magnet:?xt=urn:btih:$infoHash&dn=${Uri.encodeComponent(title)}"
                : "",
            seeds: (s['seeds'] as num?)?.toInt() ?? seedersFromTitle(rawTitle),
            provider: name,
            absoluteEpisode: context.mapping?.absoluteEpisode,
            metadata: metadata,
            resolution: metadata.video.resolution.label,
            url: streamUrl,
            headers: headers,
          );
        }).toList();
      } else {
        AppLogger.warn(_logTag, '$name: unexpected response ${res.statusCode}');
      }
    } on DioException catch (e) {
      AppLogger.warn(
        _logTag,
        '$name: fetch failed (${e.type.name}, '
        'status ${e.response?.statusCode})',
      );
    } catch (e) {
      AppLogger.warn(_logTag, '$name: unexpected error', error: e);
    }
    return [];
  }

  /// Resolves the Stremio-specific type and query ID based on context.
  ({String type, String queryId}) _resolveRequestParams(
    StreamSearchContext context,
  ) {
    if (context.mapping case final mapping?) {
      final type = context.type == 'movie' ? 'movie' : 'anime';
      final ep = mapping.absoluteEpisode ?? 1;
      final id = type == 'anime'
          ? "kitsu:${mapping.kitsuId}:$ep"
          : "kitsu:${mapping.kitsuId}";
      return (type: type, queryId: id);
    }

    final type = context.type == 'tv' ? 'series' : context.type;
    final baseId = context.imdbId ?? context.tmdbId;
    final isEpisodeQuery =
        type == 'series' && context.season != null && context.episode != null;

    return (
      type: type,
      queryId: isEpisodeQuery
          ? "$baseId:${context.season}:${context.episode}"
          : baseId,
    );
  }
}
