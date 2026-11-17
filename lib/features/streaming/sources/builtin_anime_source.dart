import 'dart:convert';

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
import 'package:html/parser.dart' as html_parser;

/// The built-in anime source: streams from the anime site's video pages.
///
/// Flow: AnimeMatch → the site's search (matched on AniList ID) → the anime's
/// episode list (one video per language) → each video's episode page → the
/// video page → HLS
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
        candidates.addAll(
          await _resolveStreams(
            found.siteAddress,
            entry,
            targetEpisode,
            context,
          ),
        );
      }
      return candidates;
    } catch (e) {
      AppLogger.warn(_logTag, 'Search failed', error: e);
      return [];
    }
  }

  /// One stream per language of [entry]'s episode [targetEpisode].
  Future<List<StreamCandidate>> _resolveStreams(
    String baseUrl,
    BuiltInAnimeEntry entry,
    int targetEpisode,
    StreamSearchContext context,
  ) async {
    try {
      final episode = await _fetchEpisode(baseUrl, entry.id, targetEpisode);
      if (episode == null) return [];

      final candidates = <StreamCandidate>[];
      // A video the site marks hidden still plays: it is used too.
      for (final video
          in (episode['videos'] as List? ?? const []).whereType<Map>()) {
        final videoId = video['id'];
        if (videoId is! int) continue;
        final embedUrl = await _fetchEmbedUrl(baseUrl, entry, videoId);
        if (embedUrl == null) continue;
        final candidate = await _extractVideoPageStream(
          baseUrl,
          embedUrl,
          episode,
          video['language']?.toString(),
          context,
        );
        if (candidate != null) candidates.add(candidate);
      }
      return candidates;
    } catch (e) {
      AppLogger.warn(_logTag, 'Failed for entry ${entry.id}', error: e);
      return [];
    }
  }

  /// The episode numbered [episodeNumber] from the anime's episode list.
  Future<Map<String, dynamic>?> _fetchEpisode(
    String baseUrl,
    int animeId,
    int episodeNumber,
  ) async {
    // The list answers up to 120 episodes from `start` on.
    final res = await _dio.get(
      '$baseUrl/api/anime/$animeId/episodes',
      queryParameters: {'start': episodeNumber},
      options: _defaultOptions(baseUrl, json: true),
    );
    if (res.statusCode != 200 || res.data == null) return null;
    final data = res.data;
    return findEpisode(data is Map ? data['episodes'] : null, episodeNumber);
  }

  /// The episode numbered [target] in [episodes]. Never falls back to another
  /// episode: playing the wrong one is worse than finding none (REV-241).
  /// Public for the daily check.
  static Map<String, dynamic>? findEpisode(Object? episodes, int target) {
    if (episodes is! List) return null;
    for (final ep in episodes.whereType<Map<String, dynamic>>()) {
      final epNum = int.tryParse(ep['number']?.toString() ?? '');
      if (epNum == target) return ep;
    }
    return null;
  }

  /// The video page's address, read from the episode page of [videoId].
  Future<String?> _fetchEmbedUrl(
    String baseUrl,
    BuiltInAnimeEntry entry,
    int videoId,
  ) async {
    final res = await _dio.get<String>(
      '$baseUrl${entry.path}/$videoId',
      options: _defaultOptions(
        baseUrl,
      ).copyWith(responseType: ResponseType.plain),
    );
    if (res.statusCode != 200 || res.data == null) return null;
    return embedUrlOf(res.data!);
  }

  /// The video page's address on an episode page: the site writes the page's
  /// data, `embedUrl` among it, into its root element's `data-page`.
  /// Public for tests and the daily check.
  static String? embedUrlOf(String html) {
    final pageData = html_parser
        .parse(html)
        .querySelector('[data-page]')
        ?.attributes['data-page'];
    if (pageData == null) return null;
    try {
      final page = jsonDecode(pageData);
      final props = page is Map ? page['props'] : null;
      final url = props is Map ? props['embedUrl'] : null;
      return url is String && url.startsWith('http') ? url : null;
    } on FormatException {
      return null;
    }
  }

  /// Extracts the HLS stream URL from a video page.
  Future<StreamCandidate?> _extractVideoPageStream(
    String baseUrl,
    String embedUrl,
    Map<String, dynamic> episode,
    String? videoLanguage,
    StreamSearchContext context,
  ) async {
    // The video page refuses a visit that doesn't come from the site.
    final res = await _dio.get(
      embedUrl,
      options: _embedOptions(referer: '$baseUrl/'),
    );
    if (res.statusCode != 200 || res.data == null) return null;

    final playlist = VideoPageParser.parse(res.data.toString());
    if (playlist == null) {
      AppLogger.warn(_logTag, 'No playlist on the video page');
      return null;
    }
    final playlistUrl = playlist.playlistUrl(addM3u8: true);
    final master = await _readPlaylist(playlistUrl, embedUrl);

    final italian = isItalianDub(videoLanguage);
    final episodeNum = episode['number']?.toString() ?? '?';

    return StreamCandidate(
      kind: StreamSourceKind.vod,
      title:
          '${context.title} Ep.$episodeNum${italian ? ' [ITA]' : ''} [$name]',
      infoHash: '',
      magnet: '',
      provider: name,
      url: playlistUrl,
      headers: {'Referer': embedUrl, 'User-Agent': _userAgent},
      metadata: StreamMetadata(
        video: VideoMetadata(resolution: master.resolution),
        audio: const AudioMetadata(),
        languages: master.languages.isNotEmpty
            ? master.languages
            : [italian ? LanguageCodes.italian : LanguageCodes.japanese],
        quality: ReleaseQuality.webdl,
      ),
    );
  }

  /// The sound languages and the biggest picture the HLS master playlist
  /// lists.
  Future<({List<String> languages, VideoResolution resolution})> _readPlaylist(
    String playlistUrl,
    String referer,
  ) async {
    const none = (languages: <String>[], resolution: VideoResolution.unknown);
    try {
      final res = await _dio.get(
        playlistUrl,
        options: Options(
          headers: {'Referer': referer, 'User-Agent': _userAgent},
        ),
      );
      if (res.statusCode != 200 || res.data == null) return none;
      return readMasterPlaylist(res.data.toString());
    } catch (e) {
      AppLogger.warn(_logTag, 'Reading the playlist failed', error: e);
      return none;
    }
  }

  /// [playlist]'s sound languages and its biggest picture. Public for tests.
  static ({List<String> languages, VideoResolution resolution})
  readMasterPlaylist(String playlist) {
    final languages = {
      for (final match in RegExp(
        r'#EXT-X-MEDIA:TYPE=AUDIO.*LANGUAGE="([^"]+)"',
      ).allMatches(playlist))
        LanguageCodes.normalize(match.group(1)!),
    }.toList();

    String? biggest;
    var biggestHeight = 0;
    for (final match in RegExp(
      r'RESOLUTION=(\d+)x(\d+)',
    ).allMatches(playlist)) {
      final height = int.parse(match.group(2)!);
      if (height > biggestHeight) {
        biggestHeight = height;
        biggest = '${match.group(1)}x$height';
      }
    }
    return (
      languages: languages,
      resolution: biggest == null
          ? VideoResolution.unknown
          : StreamParser.parse(biggest).video.resolution,
    );
  }

  /// Whether a video is the Italian dub (the site's `ita`); the others are
  /// the Japanese original with Italian subtitles.
  static bool isItalianDub(String? videoLanguage) =>
      videoLanguage?.toLowerCase() == 'ita';

  Options _defaultOptions(String baseUrl, {bool json = false}) {
    return Options(
      headers: {
        'User-Agent': _userAgent,
        'Referer': '$baseUrl/',
        if (json) 'Accept': 'application/json',
      },
      receiveTimeout: const Duration(seconds: 15),
    );
  }

  Options _embedOptions({required String referer}) {
    return Options(
      headers: {
        'Accept': '*/*',
        'Connection': 'keep-alive',
        'Cache-Control': 'no-cache',
        'Referer': referer,
        'User-Agent': _userAgent,
      },
      receiveTimeout: const Duration(seconds: 15),
    );
  }
}
