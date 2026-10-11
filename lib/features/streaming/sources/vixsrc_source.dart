import 'dart:io';
import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cinemuse_app/features/streaming/models/stream_metadata.dart';
import 'package:cinemuse_app/features/streaming/models/stream_search_context.dart';
import 'package:cinemuse_app/features/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/features/streaming/ranking/language_codes.dart';
import 'package:cinemuse_app/features/streaming/sources/base_source.dart';
import 'package:dio/dio.dart';

class VixSrcSource extends BaseSource {
  final Dio _dio;
  static const String _baseUrl = "https://vixsrc.to";

  static const String _userAgent = browserUserAgent;
  static const Duration _requestTimeout = Duration(seconds: 10);
  static const Duration _manifestMaxAge = Duration(hours: 12);
  static const String _logTag = 'VixSrcSource';

  @override
  final String name = 'VixSrc';

  VixSrcSource(this._dio);

  @override
  Set<String> get supportedCategories => {'movie', 'tv', 'series'};

  @override
  Future<List<StreamCandidate>> search(StreamSearchContext context) async {
    final String path;
    if (context.type == 'movie') {
      path = '/movie/${context.tmdbId}';
    } else if ((context.type == 'tv' || context.type == 'series') &&
        context.season != null &&
        context.episode != null) {
      path = '/tv/${context.tmdbId}/${context.season}/${context.episode}';
    } else {
      return [];
    }

    final url = '$_baseUrl$path';

    try {
      // 1. Fetch from the API first
      final apiUrl = '$_baseUrl/api$path';
      final apiResponse = await _dio.get(
        apiUrl,
        options: Options(
          headers: {
            'Referer': '$_baseUrl$path',
            'Accept': 'application/json',
            'User-Agent': _userAgent,
          },
          sendTimeout: _requestTimeout,
          receiveTimeout: _requestTimeout,
        ),
      );

      if (apiResponse.statusCode != 200 || apiResponse.data == null) {
        return [];
      }

      final src = apiResponse.data['src'];
      if (src == null) {
        return [];
      }

      // 2. Fetch the HTML from the embed page
      final embedUrl = '$_baseUrl$src';
      final response = await _dio.get(
        embedUrl,
        options: Options(
          headers: {'Referer': '$_baseUrl$path', 'User-Agent': _userAgent},
          sendTimeout: _requestTimeout,
          receiveTimeout: _requestTimeout,
        ),
      );

      if (response.statusCode != 200 || response.data == null) {
        return [];
      }

      final String html = response.data.toString();

      // 3. Extract token, expires, and playlist URL base using Regex
      final urlMatch = RegExp(r'''url:\s*['"]([^'"]+)['"]''').firstMatch(html);
      final tokenMatch = RegExp(
        r'''['"]?token['"]?:\s*['"]([^'"]+)['"]''',
      ).firstMatch(html);
      final expiresMatch = RegExp(
        r'''['"]?expires['"]?:\s*['"]([^'"]+)['"]''',
      ).firstMatch(html);

      if (tokenMatch == null || expiresMatch == null || urlMatch == null) {
        return [];
      }

      final token = tokenMatch.group(1)!;
      final expires = expiresMatch.group(1)!;
      final baseUrlStr = urlMatch.group(1)!;

      // 4. Construct the HLS Playlist URL
      final baseUrl = Uri.parse(baseUrlStr);
      final playlistUrl = Uri(
        scheme: baseUrl.scheme,
        host: baseUrl.host,
        path: baseUrl.path,
        queryParameters: {
          ...baseUrl.queryParameters,
          'token': token,
          'expires': expires,
          'h': '1',
        },
      ).toString();

      // 5. Fetch master manifest, filter down to preferred subtitles, and cache locally.
      // This prevents MPV from issuing 80+ sequential HTTP requests probing 40+ unused
      // subtitle languages, which blocks player startup for ~45 seconds.
      String finalPlaybackUrl = playlistUrl;
      List<String> audioLanguages = [];
      List<Map<String, String>> onDemandSubtitles = [];

      try {
        final playlistResponse = await _dio.get(
          playlistUrl,
          options: Options(
            headers: {'Referer': '$_baseUrl$path', 'User-Agent': _userAgent},
            sendTimeout: _requestTimeout,
            receiveTimeout: _requestTimeout,
          ),
        );

        if (playlistResponse.statusCode == 200 &&
            playlistResponse.data != null) {
          final manifestStr = playlistResponse.data.toString();
          if (manifestStr.isNotEmpty) {
            final filterResult = _filterMasterManifest(
              manifestStr,
              context.preferredLanguages,
            );
            audioLanguages = filterResult.audioLanguages;
            onDemandSubtitles = filterResult.onDemandSubtitles;
            finalPlaybackUrl = await _writeManifestToTempFile(
              filterResult.content,
              token,
            );
          }
        }
      } catch (e) {
        // Fall back to the untrimmed playlist: it plays, just starts slower.
        AppLogger.warn(_logTag, 'Could not trim the playlist', error: e);
      }

      return [
        StreamCandidate(
          kind: StreamSourceKind.vod,
          title: '${context.title} [VixSrc]',
          infoHash: '',
          magnet: '',
          provider: name,
          url: finalPlaybackUrl,
          headers: {
            'Referer': url,
            'Origin': _baseUrl,
            'User-Agent': _userAgent,
          },
          metadata: StreamMetadata(
            video: const VideoMetadata(resolution: VideoResolution.r1080p),
            audio: const AudioMetadata(),
            languages: audioLanguages.isNotEmpty
                ? audioLanguages
                : const ['ITA', 'ENG'],
            quality: ReleaseQuality.webdl,
            custom: {
              if (onDemandSubtitles.isNotEmpty)
                'onDemandSubtitles': onDemandSubtitles,
            },
          ),
        ),
      ];
    } catch (e) {
      // Logged so "offline" can be told apart from "not on VixSrc".
      AppLogger.warn(_logTag, 'Search failed for $path', error: e);
      return [];
    }
  }

  /// Filters out unused subtitle renditions to keep demuxer probe time fast (~1s).
  /// Subtitles not probed at startup are preserved in `onDemandSubtitles` so
  /// the user can still select them from the internal tracks list.
  _FilteredManifest _filterMasterManifest(
    String rawManifest,
    List<String> preferredLanguages,
  ) {
    final lines = rawManifest.split(RegExp(r'\r?\n'));
    final filteredLines = <String>[];
    final audioLanguages = <String>{};
    final preferredSubtitleLines = <String>[];
    final otherSubtitleLines = <String>[];
    final onDemandSubtitles = <Map<String, String>>[];

    for (final line in lines) {
      if (line.startsWith('#EXT-X-MEDIA:TYPE=AUDIO')) {
        final lang = _extractAttribute(line, 'LANGUAGE');
        if (lang != null && lang.isNotEmpty) {
          audioLanguages.add(LanguageCodes.normalize(lang));
        }
        filteredLines.add(line);
      } else if (line.startsWith('#EXT-X-MEDIA:TYPE=SUBTITLES')) {
        final lang = _extractAttribute(line, 'LANGUAGE') ?? '';
        final name = _extractAttribute(line, 'NAME') ?? lang;
        final uri = _extractAttribute(line, 'URI') ?? '';

        if (_isPreferredSubtitleLine(line, preferredLanguages)) {
          preferredSubtitleLines.add(line);
        } else {
          otherSubtitleLines.add(line);
          if (uri.isNotEmpty) {
            onDemandSubtitles.add({'name': name, 'language': lang, 'uri': uri});
          }
        }
      } else {
        filteredLines.add(line);
      }
    }

    // Keep preferred subtitles, or fall back to the first available language
    final List<String> finalSubtitles;
    if (preferredSubtitleLines.isNotEmpty) {
      finalSubtitles = preferredSubtitleLines;
    } else if (otherSubtitleLines.isNotEmpty) {
      final fallbackLine = otherSubtitleLines.first;
      finalSubtitles = [fallbackLine];
      final fallbackUri = _extractAttribute(fallbackLine, 'URI') ?? '';
      onDemandSubtitles.removeWhere((item) => item['uri'] == fallbackUri);
    } else {
      finalSubtitles = const [];
    }

    // Place subtitle lines before stream renditions for valid HLS ordering.
    final insertIdx = filteredLines.indexWhere(
      (l) => l.startsWith('#EXT-X-STREAM-INF'),
    );
    if (insertIdx != -1) {
      filteredLines.insertAll(insertIdx, finalSubtitles);
    } else {
      filteredLines.addAll(finalSubtitles);
    }

    return _FilteredManifest(
      content: filteredLines.join('\n'),
      audioLanguages: audioLanguages.toList(),
      onDemandSubtitles: onDemandSubtitles,
    );
  }

  String? _extractAttribute(String line, String attrName) {
    final match = RegExp('$attrName="([^"]+)"').firstMatch(line);
    return match?.group(1);
  }

  bool _isPreferredSubtitleLine(String line, List<String> preferredLanguages) {
    final lang = _extractAttribute(line, 'LANGUAGE')?.toLowerCase();
    final name = _extractAttribute(line, 'NAME')?.toLowerCase();
    if (lang == null && name == null) return false;

    for (final pref in preferredLanguages) {
      final p = pref.toLowerCase();
      if (lang != null && _matchesLanguageCode(lang, p)) {
        return true;
      }
      if (name != null && _matchesDisplayName(name, p)) {
        return true;
      }
    }
    return false;
  }

  bool _matchesLanguageCode(String lang, String pref) {
    if (lang == pref || lang == '$pref-forced') return true;
    if ((pref == 'it' || pref == 'ita') &&
        (lang == 'it' || lang == 'ita' || lang == 'ita-forced')) {
      return true;
    }
    if ((pref == 'en' || pref == 'eng') &&
        (lang == 'en' || lang == 'eng' || lang == 'eng-forced')) {
      return true;
    }
    return false;
  }

  bool _matchesDisplayName(String name, String pref) {
    if (pref == 'it' || pref == 'ita') {
      return name.startsWith('italian');
    }
    if (pref == 'en' || pref == 'eng') {
      return name.startsWith('english');
    }
    return name.startsWith(pref);
  }

  Future<String> _writeManifestToTempFile(String content, String token) async {
    Directory tempDir;
    try {
      tempDir = await getTemporaryDirectory();
    } catch (e) {
      // path_provider has no plugin in some test and desktop setups.
      AppLogger.debug(_logTag, 'No app temp folder, using the system one: $e');
      tempDir = Directory.systemTemp;
    }
    final dir = Directory('${tempDir.path}/vixsrc_playlists');
    await dir.create(recursive: true);
    await deleteStaleManifests(dir);
    final file = File('${dir.path}/vixsrc_${token.hashCode.abs()}.m3u8');
    await file.writeAsString(content);
    return file.path;
  }

  /// Deletes playlists written more than [_manifestMaxAge] ago from [dir].
  ///
  /// Every search writes a new file. Old ones can't be played again (their
  /// token has expired), so they would only pile up. Newer ones are kept:
  /// one of them may be playing right now.
  @visibleForTesting
  static Future<void> deleteStaleManifests(Directory dir) async {
    final cutoff = DateTime.now().subtract(_manifestMaxAge);
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.m3u8')) continue;
      try {
        if (entity.lastModifiedSync().isBefore(cutoff)) {
          await entity.delete();
        }
      } on FileSystemException catch (e) {
        // A leftover file only wastes a few KB; the search can go on.
        AppLogger.warn(_logTag, 'Could not delete an old playlist', error: e);
      }
    }
  }
}

class _FilteredManifest {
  final String content;
  final List<String> audioLanguages;
  final List<Map<String, String>> onDemandSubtitles;

  const _FilteredManifest({
    required this.content,
    required this.audioLanguages,
    required this.onDemandSubtitles,
  });
}
