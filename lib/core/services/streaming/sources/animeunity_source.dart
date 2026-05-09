import 'dart:convert';

import 'package:cinemuse_app/core/services/anime/kitsu_mapping_service.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_metadata.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_search_context.dart';
import 'package:cinemuse_app/core/services/streaming/sources/base_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Native anime streaming source that resolves streams from AnimeUnity via VixCloud.
///
/// Flow: KitsuMapping → Stremio mapping API → AnimeUnity episode API → VixCloud embed → HLS
class AnimeUnitySource extends BaseSource {
  static const _animeUnityBase = 'https://www.animeunity.so';
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:131.0) Gecko/20100101 Firefox/131.0';

  final Dio _dio;
  final KitsuMappingService _mappingService;

  @override
  final String name = 'AnimeUnity';

  @override
  Set<String> get supportedCategories => {'anime'};

  AnimeUnitySource(this._dio, this._mappingService);

  @override
  Future<List<StreamCandidate>> search(StreamSearchContext context) async {
    if (!context.isAnime || context.mapping == null) return [];

    final kitsuId = context.mapping!.kitsuId;
    final targetEpisode = context.mapping!.absoluteEpisode ?? context.episode;
    if (targetEpisode == null) return [];

    try {
      final entries = await _mappingService.getAnimeUnityIds(kitsuId);
      if (entries.isEmpty) return [];

      final candidates = <StreamCandidate>[];
      for (final entry in entries) {
        final result = await _resolveStream(entry, targetEpisode, context);
        if (result != null) candidates.add(result);
      }
      return candidates;
    } catch (e) {
      debugPrint('AnimeUnitySource: Search failed: $e');
      return [];
    }
  }

  /// Resolves a single AnimeUnity entry to a playable stream candidate.
  Future<StreamCandidate?> _resolveStream(
    AnimeUnityEntry entry,
    int targetEpisode,
    StreamSearchContext context,
  ) async {
    try {
      final episodeData = await _fetchEpisode(entry.id, targetEpisode);
      if (episodeData == null) return null;

      final embedUrl = await _fetchEmbedUrl(episodeData['id'] as int);
      if (embedUrl == null) return null;

      return _extractVixCloudStream(embedUrl, episodeData, context, entry);
    } catch (e) {
      debugPrint('AnimeUnitySource: Failed for entry ${entry.id}: $e');
      return null;
    }
  }

  /// Fetches the episode data from AnimeUnity's info API.
  Future<Map<String, dynamic>?> _fetchEpisode(
    int animeId,
    int episodeNumber,
  ) async {
    final url =
        '$_animeUnityBase/info_api/$animeId/1?start_range=$episodeNumber&end_range=$episodeNumber';

    final res = await _dio.get(url, options: _defaultOptions());
    if (res.statusCode != 200 || res.data == null) return null;

    final episodes = res.data['episodes'] as List?;
    if (episodes == null || episodes.isEmpty) return null;

    return _findMatchingEpisode(episodes, episodeNumber);
  }

  /// Finds the episode matching the target number from the API response.
  Map<String, dynamic>? _findMatchingEpisode(List episodes, int target) {
    for (final ep in episodes) {
      final epNum = int.tryParse(ep['number']?.toString() ?? '');
      if (epNum == target) return ep as Map<String, dynamic>;
    }
    // Fallback: return the first episode if only one is returned
    return episodes.length == 1 ? episodes.first as Map<String, dynamic> : null;
  }

  /// Fetches the VixCloud embed URL for a given episode ID.
  Future<String?> _fetchEmbedUrl(int episodeId) async {
    final url = '$_animeUnityBase/embed-url/$episodeId';

    final res = await _dio.get(
      url,
      options: _defaultOptions(followRedirects: false),
    );

    if (res.statusCode == 200 && res.data != null) {
      final body = res.data.toString().trim();
      if (body.startsWith('http')) return body;
    }

    // Check Location header for redirect-based responses
    final location = res.headers.value('location');
    if (location != null && location.startsWith('http')) return location;

    return null;
  }

  /// Extracts the HLS stream URL from a VixCloud embed page.
  Future<StreamCandidate?> _extractVixCloudStream(
    String embedUrl,
    Map<String, dynamic> episodeData,
    StreamSearchContext context,
    AnimeUnityEntry entry,
  ) async {
    final normalizedUrl =
        embedUrl.startsWith('http') ? embedUrl : 'https:$embedUrl';

    final res = await _dio.get(normalizedUrl, options: _embedOptions());
    if (res.statusCode != 200 || res.data == null) return null;

    final html = res.data.toString();
    final hlsResult = _parseVixCloudScript(html);
    if (hlsResult == null) return null;

    final languages = await _detectLanguagesFromPlaylist(
      hlsResult.url,
      normalizedUrl,
    );

    final langSuffix = _inferLanguageSuffix(entry.path);
    final episodeNum = episodeData['number']?.toString() ?? '?';
    final fileName = episodeData['file_name']?.toString() ?? '';
    final resolution = _inferResolutionFromFileName(fileName);

    return StreamCandidate(
      title: '${context.title} Ep.$episodeNum $langSuffix [$name]',
      infoHash: '',
      magnet: '',
      provider: name,
      url: hlsResult.url,
      headers: {
        'Referer': normalizedUrl,
        'User-Agent': _userAgent,
      },
      metadata: StreamMetadata(
        video: VideoMetadata(resolution: resolution),
        audio: const AudioMetadata(),
        languages: languages,
        quality: ReleaseQuality.webdl,
      ),
    );
  }

  /// Parses VixCloud embed page script to extract the master playlist URL.
  ///
  /// Looks for `window.masterPlaylist`, `window.canPlayFHD`, and builds
  /// the final `.m3u8` URL with token, expires, and FHD params.
  _VixCloudHlsResult? _parseVixCloudScript(String html) {
    // Find script tag containing masterPlaylist
    final scriptPattern =
        RegExp(r'<script[^>]*>([\s\S]*?masterPlaylist[\s\S]*?)</script>');
    final scriptMatch = scriptPattern.firstMatch(html);
    if (scriptMatch == null) {
      debugPrint('AnimeUnitySource: No masterPlaylist script found');
      return null;
    }
    final script = scriptMatch.group(1)!;

    final url = _extractWindowValue(script, 'masterPlaylistUrl') ??
        _extractMasterPlaylistUrl(script);
    if (url == null || url.isEmpty) {
      debugPrint('AnimeUnitySource: masterPlaylist.url not found');
      return null;
    }

    final token = _extractParamValue(script, 'token');
    final expires = _extractParamValue(script, 'expires');
    final canPlayFHD = script.contains('canPlayFHD') &&
        RegExp(r'canPlayFHD\s*[:=]\s*true', caseSensitive: false)
            .hasMatch(script);

    return _buildHlsUrl(url, token, expires, canPlayFHD);
  }

  /// Extracts a value assigned to `window.<key>` from a script block.
  String? _extractWindowValue(String script, String key) {
    final pattern =
        RegExp('window\\.$key\\s*=\\s*[\'"]([^\'"]*?)[\'"]');
    return pattern.firstMatch(script)?.group(1);
  }

  /// Extracts the `url` field from a `masterPlaylist` object literal.
  String? _extractMasterPlaylistUrl(String script) {
    final pattern = RegExp(r'''url\s*:\s*['"]([^'"]+?)['"]''');
    return pattern.firstMatch(script)?.group(1);
  }

  /// Extracts a named param (token/expires) from script content.
  String? _extractParamValue(String script, String paramName) {
    final pattern =
        RegExp('''['"]?$paramName['"]?\\s*:\\s*['"]([^'"]*?)['"]''');
    return pattern.firstMatch(script)?.group(1);
  }

  /// Builds the final HLS `.m3u8` URL with authentication params.
  _VixCloudHlsResult? _buildHlsUrl(
    String baseUrl,
    String? token,
    String? expires,
    bool canPlayFHD,
  ) {
    if (token == null || expires == null) {
      debugPrint('AnimeUnitySource: Missing token or expires');
      return null;
    }

    var finalUrl = baseUrl;

    // Ensure .m3u8 extension
    final beforeQuery = finalUrl.split('?')[0];
    if (!beforeQuery.endsWith('.m3u8')) {
      final parts = finalUrl.split('?');
      finalUrl = '${beforeQuery.replaceAll(RegExp(r'/$'), '')}.m3u8';
      if (parts.length > 1) finalUrl += '?${parts.sublist(1).join('?')}';
    }

    // Add authentication params
    final separator = finalUrl.contains('?') ? '&' : '?';
    finalUrl += '${separator}token=${Uri.encodeComponent(token)}'
        '&expires=${Uri.encodeComponent(expires)}';

    if (canPlayFHD) finalUrl += '&h=1';

    return _VixCloudHlsResult(url: finalUrl);
  }

  /// Detects audio languages from the HLS master playlist.
  Future<List<String>> _detectLanguagesFromPlaylist(
    String playlistUrl,
    String referer,
  ) async {
    try {
      final res = await _dio.get(
        playlistUrl,
        options: Options(headers: {
          'Referer': referer,
          'User-Agent': _userAgent,
        }),
      );
      if (res.statusCode != 200 || res.data == null) return [];

      final playlist = res.data.toString();
      final languages = <String>{};
      final matches = RegExp(r'#EXT-X-MEDIA:TYPE=AUDIO.*LANGUAGE="([^"]+)"')
          .allMatches(playlist);
      for (final match in matches) {
        languages.add(match.group(1)!.toUpperCase());
      }
      return languages.toList();
    } catch (e) {
      debugPrint('AnimeUnitySource: Language detection failed: $e');
      return [];
    }
  }

  /// Infers language hint from the AnimeUnity slug (e.g. `-ita` suffix).
  String _inferLanguageSuffix(String path) {
    final lower = path.toLowerCase();
    if (lower.contains('-ita')) return '[ITA]';
    if (lower.contains('-sub')) return '[SUB-ITA]';
    return '';
  }

  /// Infers video resolution from the episode file name.
  VideoResolution _inferResolutionFromFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.contains('2160p') || lower.contains('4k')) {
      return VideoResolution.r2160p;
    }
    if (lower.contains('1080p')) return VideoResolution.r1080p;
    if (lower.contains('720p')) return VideoResolution.r720p;
    if (lower.contains('480p')) return VideoResolution.r480p;
    return VideoResolution.unknown;
  }

  Options _defaultOptions({bool followRedirects = true}) {
    return Options(
      headers: {
        'User-Agent': _userAgent,
        'Referer': _animeUnityBase,
      },
      followRedirects: followRedirects,
      receiveTimeout: const Duration(seconds: 15),
    );
  }

  Options _embedOptions() {
    return Options(
      headers: {
        'Accept': '*/*',
        'Connection': 'keep-alive',
        'Cache-Control': 'no-cache',
        'User-Agent': _userAgent,
      },
      receiveTimeout: const Duration(seconds: 15),
    );
  }
}

class _VixCloudHlsResult {
  final String url;
  _VixCloudHlsResult({required this.url});
}
