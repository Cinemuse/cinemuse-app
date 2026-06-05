import 'package:cinemuse_app/core/services/streaming/models/stream_metadata.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_search_context.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/streaming/sources/base_source.dart';
import 'package:dio/dio.dart';

class VixSrcSource extends BaseSource {
  final Dio _dio;
  static const String _baseUrl = "https://vixsrc.to";

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
          headers: {'Referer': '$_baseUrl$path', 'Accept': 'application/json'},
        ),
      );

      if (apiResponse.statusCode != 200 || apiResponse.data == null) {
        return [];
      }

      final src = apiResponse.data['src'];
      if (src == null) return [];

      // 2. Fetch the HTML from the embed page
      final embedUrl = '$_baseUrl$src';
      final response = await _dio.get(
        embedUrl,
        options: Options(headers: {'Referer': '$_baseUrl$path'}),
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

      // Return the candidate immediately. Language/subtitle metadata is not
      // pre-fetched here because downloading the HLS master playlist adds
      // ~30s of latency before playback begins. The player's TrackManager
      // reactively selects the correct audio/subtitle tracks once the stream
      // is opened and demuxed.
      return [
        StreamCandidate(
          kind: StreamSourceKind.vod,
          title: '${context.title} [VixSrc]',
          infoHash: '',
          magnet: '',
          provider: name,
          url: playlistUrl,
          headers: {
            'Referer': url,
            'Origin': _baseUrl,
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
          metadata: StreamMetadata(
            video: const VideoMetadata(resolution: VideoResolution.r1080p),
            audio: const AudioMetadata(),
            languages: const [],
            quality: ReleaseQuality.webdl,
          ),
        ),
      ];
    } catch (e) {
      return [];
    }
  }
}
