import 'package:cinemuse_app/core/services/streaming/models/stream_metadata.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_search_context.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/streaming/sources/base_source.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

class VixSrcSource extends BaseSource {
  final Dio _dio;
  static const String _baseUrl = "https://vixsrc.to";

  @override
  final String name = 'VixSrc';

  VixSrcSource(this._dio);

  @override
  Set<String> get supportedCategories => {'movie', 'tv'};

  @override
  Future<List<StreamCandidate>> search(StreamSearchContext context) async {
    final String path;
    if (context.type == 'movie') {
      path = '/movie/${context.tmdbId}';
    } else if (context.type == 'tv' && context.season != null && context.episode != null) {
      path = '/tv/${context.tmdbId}/${context.season}/${context.episode}';
    } else {
      return [];
    }

    final url = '$_baseUrl$path';
    
    try {
      // 1. Fetch the HTML from the embed page
      final response = await _dio.get(url, options: Options(headers: {'Referer': url}));
      if (response.statusCode != 200 || response.data == null) {
        return [];
      }

      final String html = response.data.toString();

      // 2. Extract token, expires, and playlist URL base using Regex
      final tokenMatch = RegExp(r'''['"]token['"]:\s?['"](.*?)['"]''').firstMatch(html);
      final expiresMatch = RegExp(r'''['"]expires['"]:\s?['"](.*?)['"]''').firstMatch(html);
      final urlMatch = RegExp(r'''url:\s?['"](.*?)['"]''').firstMatch(html);

      if (tokenMatch == null || expiresMatch == null || urlMatch == null) {
        debugPrint('VixSrcSource: Failed to extract tokens from HTML');
        return [];
      }

      final token = tokenMatch.group(1)!;
      final expires = expiresMatch.group(1)!;
      final baseUrlStr = urlMatch.group(1)!;

      // 3. Construct the HLS Playlist URL
      final baseUrl = Uri.parse(baseUrlStr);
      final playlistUrl = Uri(
        scheme: baseUrl.scheme,
        host: baseUrl.host,
        path: '${baseUrl.path}.m3u8',
        queryParameters: {
          ...baseUrl.queryParameters,
          'token': token,
          'expires': expires,
          'h': '1',
        },
      ).toString();

      // 4. Determine languages from the playlist
      final languages = await _determineLanguagesFromPlaylist(playlistUrl, url);

      return [
        StreamCandidate(
          title: '${context.title} [VixSrc]',
          infoHash: '',
          magnet: '',
          provider: name,
          url: playlistUrl,
          headers: {'Referer': url},
          metadata: StreamMetadata(
            video: const VideoMetadata(resolution: VideoResolution.r1080p), // Vix usually has 1080p
            audio: const AudioMetadata(),
            languages: languages,
            quality: ReleaseQuality.webdl,
          ),
        ),
      ];
    } catch (e) {
      debugPrint('VixSrcSource: Search failed: $e');
      return [];
    }
  }

  Future<List<String>> _determineLanguagesFromPlaylist(String playlistUrl, String referer) async {
    try {
      final response = await _dio.get(playlistUrl, options: Options(headers: {'Referer': referer}));
      if (response.statusCode != 200 || response.data == null) return [];

      final String playlist = response.data.toString();
      final Set<String> foundLanguages = {};

      // Match #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="...",NAME="...",LANGUAGE="it",...
      final matches = RegExp(r'#EXT-X-MEDIA:TYPE=AUDIO.*LANGUAGE="([^"]+)"').allMatches(playlist);
      for (final match in matches) {
        final lang = match.group(1)!.toUpperCase();
        // Normalize common codes if needed, but usually it's "IT", "EN", etc.
        foundLanguages.add(lang);
      }

      return foundLanguages.toList();
    } catch (e) {
      debugPrint('VixSrcSource: Failed to determine languages: $e');
      return [];
    }
  }
}
