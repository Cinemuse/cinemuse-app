import 'package:cinemuse_app/core/services/streaming/subtitles/external_subtitle.dart';
import 'package:cinemuse_app/core/services/streaming/subtitles/subtitle_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class OpenSubtitlesProvider implements SubtitleProvider {
  final String _apiKey;
  final Dio _dio;
  
  static const String _baseUrl = 'https://api.opensubtitles.com/api/v1';

  OpenSubtitlesProvider(this._apiKey) : _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    headers: {
      'Api-Key': _apiKey,
      'Accept': 'application/json',
      'User-Agent': 'cinemuse v1.0.0'
    },
    validateStatus: (status) => true,
  ));

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
    if (!isReady) return [];

    try {
      final queryParams = <String, dynamic>{
        'languages': language,
        'order_by': 'download_count',
        'order_direction': 'desc',
      };

      if (imdbId != null && imdbId.isNotEmpty) {
        // OpenSubtitles expects IMDb IDs without 'tt'
        queryParams['imdb_id'] = imdbId.replaceAll('tt', '');
      } else if (tmdbId != null && tmdbId.isNotEmpty) {
        queryParams['tmdb_id'] = tmdbId;
      } else if (query != null && query.isNotEmpty) {
        queryParams['query'] = query;
      } else {
        return [];
      }

      if (season != null) queryParams['season_number'] = season;
      if (episode != null) queryParams['episode_number'] = episode;

      final response = await _dio.get('/subtitles', queryParameters: queryParams);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? [];
        final List<ExternalSubtitle> results = [];

        for (var item in data) {
          final attrs = item['attributes'];
          final files = attrs['files'] as List<dynamic>?;
          if (files == null || files.isEmpty) continue;

          // usually just one file, but we'll take the first one
          final fileInfo = files[0];
          
          results.add(ExternalSubtitle(
            id: fileInfo['file_id'].toString(),
            language: attrs['language']?.toString() ?? language,
            languageName: attrs['language']?.toString() ?? language,
            format: 'srt', // OS API usually returns srt
            providerName: name,
            title: fileInfo['file_name']?.toString() ?? 'Unknown',
            rating: (attrs['ratings'] != null) ? (attrs['ratings'] as num).toDouble() : null,
            downloadCount: (attrs['download_count'] != null) ? (attrs['download_count'] as num).toInt() : null,
          ));
        }
        return results;
      } else {
        debugPrint('OpenSubtitles search error: ${response.statusCode} - ${response.data}');
      }
    } catch (e) {
      debugPrint('OpenSubtitles exception: $e');
    }
    return [];
  }

  @override
  Future<String?> getDownloadUrl(ExternalSubtitle subtitle) async {
    if (!isReady) return null;

    try {
      final response = await _dio.post('/download', data: {
        'file_id': int.tryParse(subtitle.id) ?? subtitle.id,
      });

      if (response.statusCode == 200) {
        return response.data['link']?.toString();
      } else if (response.statusCode == 406 || response.statusCode == 429) {
        debugPrint('OpenSubtitles download error: Rate limit exceeded');
      } else {
        debugPrint('OpenSubtitles download error: ${response.statusCode} - ${response.data}');
      }
    } catch (e) {
      debugPrint('OpenSubtitles download exception: $e');
    }
    return null;
  }
}
