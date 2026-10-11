import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'dart:io';
import 'package:cinemuse_app/features/streaming/subtitles/external_subtitle.dart';
import 'package:cinemuse_app/features/streaming/subtitles/subtitle_provider.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Subtitle provider backed by the OpenSubtitles.com REST API (v1).
class OpenSubtitlesProvider implements SubtitleProvider {
  static const String _logTag = 'OpenSubtitlesProvider';

  final String _apiKey;
  final Dio _dio;

  static const String _baseUrl = 'https://api.opensubtitles.com/api/v1';
  static const String _userAgent = 'Cinemuse v1.0.0';

  OpenSubtitlesProvider(this._apiKey)
    : _dio = Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          headers: {
            'Api-Key': _apiKey,
            'Accept': 'application/json',
            'User-Agent': _userAgent,
            'X-User-Agent': _userAgent,
          },
          validateStatus: (status) => true,
        ),
      ) {
    // Set User-Agent at the transport level so dart:io doesn't override it
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.userAgent = _userAgent;
      return client;
    };
  }

  /// Closes the HTTP client. Requests already running still finish.
  void close() => _dio.close();

  @override
  String get name => 'OpenSubtitles.com';

  @override
  bool get isReady => _apiKey.isNotEmpty;

  @override
  Future<List<ExternalSubtitle>> search({
    String? imdbId,
    String? tmdbId,
    int? season,
    int? episode,
    String? query,
    required String language,
  }) async {
    if (!isReady) {
      AppLogger.debug(_logTag, 'Not ready (API key empty)');
      return [];
    }

    try {
      final queryParams = _buildSearchParams(
        imdbId: imdbId,
        tmdbId: tmdbId,
        season: season,
        episode: episode,
        query: query,
        language: language,
      );
      if (queryParams == null) {
        AppLogger.debug(
          _logTag,
          'No valid search params (imdb=$imdbId, tmdb=$tmdbId, query=$query)',
        );
        return [];
      }

      AppLogger.debug(_logTag, 'Searching: $queryParams');
      final response = await _dio.get(
        '/subtitles',
        queryParameters: queryParams,
      );
      AppLogger.debug(_logTag, 'Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final results = _parseSearchResults(response.data, language);
        AppLogger.debug(_logTag, 'Found ${results.length} subtitles');
        return results;
      } else {
        AppLogger.warn(
          _logTag,
          'Error response: ${response.statusCode} — ${response.data}',
        );
      }
    } catch (e, st) {
      AppLogger.warn(
        _logTag,
        'Exception during search',
        error: e,
        stackTrace: st,
      );
    }

    return [];
  }

  @override
  Future<String?> getDownloadUrl(ExternalSubtitle subtitle) async {
    if (!isReady) return null;

    try {
      AppLogger.debug(_logTag, 'Downloading file_id=${subtitle.id}');
      final response = await _dio.post(
        '/download',
        data: {'file_id': int.tryParse(subtitle.id) ?? subtitle.id},
      );

      if (response.statusCode == 200) {
        AppLogger.debug(_logTag, 'Download URL obtained');
        return response.data['link']?.toString();
      } else {
        AppLogger.warn(
          _logTag,
          'Download failed: ${response.statusCode} — ${response.data}',
        );
      }
    } catch (e) {
      AppLogger.warn(_logTag, 'Download exception', error: e);
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Builds the query parameters map for the /subtitles endpoint.
  /// Returns `null` if no valid identifier is provided.
  Map<String, dynamic>? _buildSearchParams({
    String? imdbId,
    String? tmdbId,
    int? season,
    int? episode,
    String? query,
    required String language,
  }) {
    final params = <String, dynamic>{
      'languages': language,
      'order_by': 'download_count',
      'order_direction': 'desc',
    };

    if (imdbId != null && imdbId.isNotEmpty) {
      params['imdb_id'] = imdbId.replaceAll('tt', '');
    } else if (tmdbId != null && tmdbId.isNotEmpty) {
      _addTmdbParams(params, tmdbId, season: season, episode: episode);
    } else if (query != null && query.isNotEmpty) {
      params['query'] = query;
    } else {
      return null;
    }

    if (season != null && season > 0) params['season_number'] = season;
    if (episode != null && episode > 0) params['episode_number'] = episode;

    return params;
  }

  /// Adds the correct TMDB parameter depending on content type.
  ///
  /// For TV series (with season/episode), uses `parent_tmdb_id` + `type=episode`.
  /// For movies, uses `tmdb_id` + `type=movie`.
  void _addTmdbParams(
    Map<String, dynamic> params,
    String tmdbId, {
    int? season,
    int? episode,
  }) {
    final parsedId = int.tryParse(tmdbId) ?? tmdbId;
    final isSeries =
        (season != null && season > 0) && (episode != null && episode > 0);

    params['type'] = isSeries ? 'episode' : 'movie';
    params[isSeries ? 'parent_tmdb_id' : 'tmdb_id'] = parsedId;
  }

  /// Parses the raw API response into a list of [ExternalSubtitle].
  List<ExternalSubtitle> _parseSearchResults(
    dynamic responseData,
    String fallbackLanguage,
  ) {
    final List<dynamic> data = responseData['data'] ?? [];
    return data
        .map((item) => _parseSubtitleEntry(item, fallbackLanguage))
        .whereType<ExternalSubtitle>()
        .toList();
  }

  /// Parses a single subtitle entry from the API response.
  /// Returns `null` if the entry has no files.
  ExternalSubtitle? _parseSubtitleEntry(dynamic item, String fallbackLanguage) {
    final attrs = item['attributes'];
    final files = attrs['files'] as List<dynamic>?;
    if (files == null || files.isEmpty) return null;

    final fileInfo = files[0];
    return ExternalSubtitle(
      id: fileInfo['file_id'].toString(),
      language: attrs['language']?.toString() ?? fallbackLanguage,
      format: 'srt',
      providerName: name,
      title: fileInfo['file_name']?.toString() ?? 'Unknown',
      rating: (attrs['ratings'] as num?)?.toDouble(),
      downloadCount: (attrs['download_count'] as num?)?.toInt(),
    );
  }
}
