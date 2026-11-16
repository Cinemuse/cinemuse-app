import 'package:cinemuse_app/core/data/server_addresses_model.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/streaming/anime/interfaces/builtin_anime_lookup.dart';
import 'package:cinemuse_app/features/streaming/anime/models/builtin_anime_entry.dart';
import 'package:cinemuse_app/features/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/features/streaming/ranking/language_codes.dart';
import 'package:cinemuse_app/features/streaming/ranking/stream_parser.dart';
import 'package:cinemuse_app/features/streaming/models/stream_metadata.dart';
import 'package:cinemuse_app/features/streaming/models/stream_search_context.dart';
import 'package:cinemuse_app/features/streaming/sources/base_source.dart';
import 'package:cinemuse_app/features/streaming/sources/video_page_parser.dart';
import 'package:dio/dio.dart';

/// The built-in anime source: streams from the anime site's video pages.
///
/// Flow: AnimeMatch → the site's search (matched on AniList ID) → the site's
/// episode API → video page → HLS
class BuiltInAnimeSource extends BaseSource {
  static const String _logTag = 'BuiltInAnimeSource';

  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:131.0) Gecko/20100101 Firefox/131.0';

  final Dio _dio;
  final BuiltInAnimeLookup _mappingService;

  /// The site's address comes from the server's list (STR-08).
  final ServerAddressesLoader _loadAddresses;

  /// The site's name, from the server's list too.
  @override
  final String name;

  @override
  Set<String> get supportedCategories => {'anime'};

  BuiltInAnimeSource(
    this._dio,
    this._mappingService,
    this._loadAddresses, {
    required this.name,
  });

  @override
  Future<List<StreamCandidate>> search(StreamSearchContext context) async {
    if (!context.isAnime || context.mapping == null) return [];

    final targetEpisode = context.mapping!.absoluteEpisode ?? context.episode;
    if (targetEpisode == null) return [];

    try {
      final listed = (await _loadAddresses()).baseUrl(ServerAddress.animeSite);
      if (listed == null) {
        AppLogger.warn(_logTag, 'No anime site address in the site list');
        return [];
      }
      final found = await _mappingService.findEntries(context.mapping!);
      if (found == null) return [];

      final candidates = <StreamCandidate>[];
      for (final entry in found.entries) {
        final result = await _resolveStream(
          found.siteAddress,
          entry,
          targetEpisode,
          context,
        );
        if (result != null) candidates.add(result);
      }
      return candidates;
    } catch (e) {
      AppLogger.warn(_logTag, 'Search failed', error: e);
      return [];
    }
  }

  /// Resolves a single entry on the site to a playable stream candidate.
  Future<StreamCandidate?> _resolveStream(
    String baseUrl,
    BuiltInAnimeEntry entry,
    int targetEpisode,
    StreamSearchContext context,
  ) async {
    try {
      final episodeData = await _fetchEpisode(baseUrl, entry.id, targetEpisode);
      if (episodeData == null) return null;

      final embedUrl = await _fetchEmbedUrl(baseUrl, episodeData['id'] as int);
      if (embedUrl == null) return null;

      return _extractVideoPageStream(embedUrl, episodeData, context, entry);
    } catch (e) {
      AppLogger.warn(_logTag, 'Failed for entry ${entry.id}', error: e);
      return null;
    }
  }

  /// Fetches the episode data from the site's info API.
  Future<Map<String, dynamic>?> _fetchEpisode(
    String baseUrl,
    int animeId,
    int episodeNumber,
  ) async {
    final url =
        '$baseUrl/info_api/$animeId/1?start_range=$episodeNumber&end_range=$episodeNumber';

    final res = await _dio.get(url, options: _defaultOptions(baseUrl));
    if (res.statusCode != 200 || res.data == null) return null;

    final episodes = res.data['episodes'] as List?;
    if (episodes == null || episodes.isEmpty) return null;

    return _findMatchingEpisode(episodes, episodeNumber);
  }

  /// Finds the episode numbered [target]. Never falls back to another
  /// episode: playing the wrong one is worse than finding none (REV-241).
  Map<String, dynamic>? _findMatchingEpisode(List episodes, int target) {
    for (final ep in episodes) {
      final epNum = int.tryParse(ep['number']?.toString() ?? '');
      if (epNum == target) return ep as Map<String, dynamic>;
    }
    return null;
  }

  /// Fetches the video page's URL for a given episode ID.
  Future<String?> _fetchEmbedUrl(String baseUrl, int episodeId) async {
    final url = '$baseUrl/embed-url/$episodeId';

    final res = await _dio.get(
      url,
      options: _defaultOptions(baseUrl, followRedirects: false),
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

  /// Extracts the HLS stream URL from a video page.
  Future<StreamCandidate?> _extractVideoPageStream(
    String embedUrl,
    Map<String, dynamic> episodeData,
    StreamSearchContext context,
    BuiltInAnimeEntry entry,
  ) async {
    final normalizedUrl = embedUrl.startsWith('http')
        ? embedUrl
        : 'https:$embedUrl';

    final res = await _dio.get(normalizedUrl, options: _embedOptions());
    if (res.statusCode != 200 || res.data == null) return null;

    final html = res.data.toString();
    final playlist = VideoPageParser.parse(html);
    if (playlist == null) {
      AppLogger.warn(_logTag, 'No playlist on the video page');
      return null;
    }
    final playlistUrl = playlist.playlistUrl(addM3u8: true);

    final languages = await _detectLanguagesFromPlaylist(
      playlistUrl,
      normalizedUrl,
    );

    final langSuffix = _inferLanguageSuffix(entry.path);
    final episodeNum = episodeData['number']?.toString() ?? '?';
    final fileName = episodeData['file_name']?.toString() ?? '';
    final resolution = StreamParser.parse(fileName).video.resolution;

    return StreamCandidate(
      kind: StreamSourceKind.vod,
      title: '${context.title} Ep.$episodeNum $langSuffix [$name]',
      infoHash: '',
      magnet: '',
      provider: name,
      url: playlistUrl,
      headers: {'Referer': normalizedUrl, 'User-Agent': _userAgent},
      metadata: StreamMetadata(
        video: VideoMetadata(resolution: resolution),
        audio: const AudioMetadata(),
        languages: languages.isNotEmpty
            ? languages
            : [_soundLanguage(entry.path)],
        quality: ReleaseQuality.webdl,
      ),
    );
  }

  /// Detects audio languages from the HLS master playlist.
  Future<List<String>> _detectLanguagesFromPlaylist(
    String playlistUrl,
    String referer,
  ) async {
    try {
      final res = await _dio.get(
        playlistUrl,
        options: Options(
          headers: {'Referer': referer, 'User-Agent': _userAgent},
        ),
      );
      if (res.statusCode != 200 || res.data == null) return [];

      final playlist = res.data.toString();
      final languages = <String>{};
      final matches = RegExp(
        r'#EXT-X-MEDIA:TYPE=AUDIO.*LANGUAGE="([^"]+)"',
      ).allMatches(playlist);
      for (final match in matches) {
        languages.add(LanguageCodes.normalize(match.group(1)!));
      }
      return languages.toList();
    } catch (e) {
      AppLogger.warn(_logTag, 'Language detection failed', error: e);
      return [];
    }
  }

  /// The sound's language when the playlist doesn't list it: the site's
  /// Italian dub entries end in `-ita`, the others are the Japanese original
  /// with Italian subtitles.
  static String _soundLanguage(String path) =>
      path.toLowerCase().endsWith('-ita')
      ? LanguageCodes.italian
      : LanguageCodes.japanese;

  /// Infers language hint from the site's slug (e.g. `-ita` suffix).
  String _inferLanguageSuffix(String path) {
    final lower = path.toLowerCase();
    if (lower.contains('-ita')) return '[ITA]';
    if (lower.contains('-sub')) return '[SUB-ITA]';
    return '';
  }

  Options _defaultOptions(String baseUrl, {bool followRedirects = true}) {
    return Options(
      headers: {'User-Agent': _userAgent, 'Referer': baseUrl},
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
