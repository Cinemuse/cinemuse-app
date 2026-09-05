import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_metadata.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_search_context.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/streaming/sources/base_source.dart';
import 'package:dio/dio.dart';

class VixSrcSource extends BaseSource {
  final Dio _dio;
  static const String _baseUrl = "https://vixsrc.to";

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  static const Duration _requestTimeout = Duration(seconds: 10);

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
          headers: {
            'Referer': '$_baseUrl$path',
            'User-Agent': _userAgent,
          },
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
            headers: {
              'Referer': '$_baseUrl$path',
              'User-Agent': _userAgent,
            },
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
      } catch (_) {
        // Fall back to direct playlistUrl if manifest filtering fails
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
          audioLanguages.add(_normalizeLangCode(lang));
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
            onDemandSubtitles.add({
              'name': name,
              'language': lang,
              'uri': uri,
            });
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

  String _normalizeLangCode(String lang) {
    final l = lang.toLowerCase();
    if (l.startsWith('it')) return 'ITA';
    if (l.startsWith('en')) return 'ENG';
    return l.toUpperCase();
  }

  Future<String> _writeManifestToTempFile(String content, String token) async {
    Directory tempDir;
    try {
      tempDir = await getTemporaryDirectory();
    } catch (_) {
      tempDir = Directory.systemTemp;
    }
    final file = File('${tempDir.path}/vixsrc_${token.hashCode.abs()}.m3u8');
    await file.writeAsString(content);
    return file.path;
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
