import 'dart:convert';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:cinemuse_app/features/media/domain/tvtime_comment.dart';

/// Internal scraper for the TVTime comment system.
///
/// TVTime does not expose a public API. This service reverse-engineers the
/// internal sidecar proxy at `side-api.tvtime.com` and scrapes the HTML
/// search/show pages to resolve entity UUIDs.
///
/// Resolution strategy:
/// - **Series**: TVDB ID → sidecar `/v1/series/<tvdbId>` → `uuid`
/// - **Movie**:  IMDB ID → scrape `/discover/search?q=<imdbId>` → UUID in href
/// - **Episode**: TVDB show ID → scrape `/show/<tvdbId>` page → episode UUID map
///
/// All public methods return empty lists on any failure and never throw.
class TvTimeService {
  static const _sidecarBase =
      'https://side-api.tvtime.com/sidecar/tvtcached?o=';
  static const _msApiBase = 'https://msapi.tvtime.com/v1';
  static const _commentsBase =
      'https://comments.tvtime.com/v1/comments/cgw/entity';
  static const _webBase = 'https://www.tvtime.com';

  // TVTime IDs 81189 = TVDB ID used for sidecar. Series in URLs use TVDB IDs.
  static const _movieHrefPrefix = '/movie/';
  static const _showHrefPrefix = '/show/';

  final Dio _dio;

  TvTimeService(this._dio);

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Fetches comments for a **series** given its TVDB ID.
  ///
  /// Pass the raw TVDB ID integer (e.g. 81189 for Breaking Bad).
  /// This is available from TMDB's `external_ids.tvdb_id` field.
  Future<List<TvTimeComment>> fetchSeriesComments(
    int tvdbId, {
    String sort = 'most_liked',
    int limit = 20,
  }) async {
    try {
      final uuid = await _resolveSeriesUuid(tvdbId);
      if (uuid == null) return [];
      return _fetchCommentsByUuid(uuid, sort: sort, limit: limit);
    } catch (_) {
      return [];
    }
  }

  /// Fetches comments for a **movie** given its IMDB ID (e.g. `tt1375666`).
  ///
  /// IMDB ID is available from TMDB's `external_ids.imdb_id` field.
  Future<List<TvTimeComment>> fetchMovieComments(
    String imdbId, {
    String sort = 'most_liked',
    int limit = 20,
  }) async {
    try {
      final uuid = await _resolveMovieUuidBySearch(imdbId);
      if (uuid == null) return [];
      return _fetchCommentsByUuid(uuid, sort: sort, limit: limit);
    } catch (_) {
      return [];
    }
  }

  /// Fetches comments for a specific **episode** given the TVDB show ID,
  /// season number, and episode number.
  ///
  /// This method scrapes the TVTime show page to build an episode UUID map.
  Future<List<TvTimeComment>> fetchEpisodeComments(
    int tvdbShowId, {
    required int season,
    required int episode,
    String sort = 'most_liked',
    int limit = 20,
  }) async {
    try {
      final uuid = await _resolveEpisodeUuid(
        tvdbShowId,
        season: season,
        episode: episode,
      );
      if (uuid == null) return [];
      return _fetchCommentsByUuid(uuid, sort: sort, limit: limit);
    } catch (_) {
      return [];
    }
  }

  // ─── UUID Resolution ───────────────────────────────────────────────────────

  /// Resolves the entity UUID for a series from the sidecar API.
  Future<String?> resolveSeriesUuid(int tvdbId) => _resolveSeriesUuid(tvdbId);

  /// Resolves the entity UUID for a movie from the TVTime search page.
  Future<String?> resolveMovieUuid(String imdbId) =>
      _resolveMovieUuidBySearch(imdbId);

  /// Resolves the entity UUID for an episode by scraping the show page.
  Future<String?> resolveEpisodeUuid(
    int tvdbShowId, {
    required int season,
    required int episode,
  }) =>
      _resolveEpisodeUuid(tvdbShowId, season: season, episode: episode);

  // ─── Internal Resolution Helpers ──────────────────────────────────────────

  Future<String?> _resolveSeriesUuid(int tvdbId) async {
    final encodedUrl =
        Uri.encodeComponent('$_msApiBase/series/$tvdbId');
    final response = await _dio.get('$_sidecarBase$encodedUrl');
    final data = _extractDataMap(response.data);
    return data?['uuid']?.toString();
  }

  Future<String?> _resolveMovieUuidBySearch(String imdbId) async {
    final searchUrl = '$_webBase/discover/search?q=${Uri.encodeComponent(imdbId)}';
    final response = await _dio.get<String>(
      searchUrl,
      options: Options(
        headers: _browserHeaders,
        responseType: ResponseType.plain,
      ),
    );

    final html = response.data ?? '';
    return _parseMovieUuidFromHtml(html);
  }

  Future<String?> _resolveEpisodeUuid(
    int tvdbShowId, {
    required int season,
    required int episode,
  }) async {
    final showUrl = '$_webBase/show/$tvdbShowId';
    final response = await _dio.get<String>(
      showUrl,
      options: Options(
        headers: _browserHeaders,
        responseType: ResponseType.plain,
      ),
    );

    final html = response.data ?? '';
    return _parseEpisodeUuidFromHtml(html, season: season, episode: episode);
  }

  // ─── HTML Parsers ──────────────────────────────────────────────────────────

  /// Parses a movie UUID from TVTime search result HTML.
  ///
  /// Looks for the first `href="/movie/<uuid>"` anchor in the page.
  String? _parseMovieUuidFromHtml(String html) {
    // Pattern: href="/movie/1be8d227-5d39-4561-8dfa-7520b8c51d0f"
    final pattern = RegExp(r'href="\/movie\/([0-9a-f\-]{36})"');
    final match = pattern.firstMatch(html);
    return match?.group(1);
  }

  /// Parses an episode UUID from the TVTime show page HTML.
  ///
  /// Each episode anchor has an href like:
  /// `https://app.tvtime.com/show/<show_uuid>/episode/<episode_uuid>`
  /// and a label like `S01 | E01`.
  String? _parseEpisodeUuidFromHtml(
    String html, {
    required int season,
    required int episode,
  }) {
    // Pattern for episode links: https://app.tvtime.com/show/<uuid>/episode/<uuid>
    // Season label appears nearby: S01 | E01
    final episodePattern = RegExp(
      r'href="https://app\.tvtime\.com/show/[^/]+/episode/([0-9a-f\-]{36})"[^>]*>[^<]*'
      r'(?:<[^>]+>)*[^<]*S(\d+)\s*\|\s*E(\d+)',
      dotAll: true,
    );

    final paddedSeason = season.toString().padLeft(2, '0');
    final paddedEpisode = episode.toString().padLeft(2, '0');

    for (final match in episodePattern.allMatches(html)) {
      final matchSeason = match.group(2);
      final matchEpisode = match.group(3);
      if (matchSeason == paddedSeason && matchEpisode == paddedEpisode) {
        return match.group(1);
      }
    }

    // Fallback: simpler two-pass approach
    return _parseEpisodeUuidTwoPass(html, season: season, episode: episode);
  }

  /// Two-pass fallback episode parser: finds all episode hrefs with their labels.
  String? _parseEpisodeUuidTwoPass(
    String html, {
    required int season,
    required int episode,
  }) {
    // Find all blocks: <a class="episodes" href="...app.tvtime.com/.../episode/<uuid>">...S01 | E01...</a>
    final anchorPattern = RegExp(
      r'href="https://app\.tvtime\.com/show/[^/]+/episode/([0-9a-f\-]{36})"',
    );
    final labelPattern = RegExp(r'S(\d+)\s*\|\s*E(\d+)');

    final anchors = anchorPattern.allMatches(html).toList();
    final labels = labelPattern.allMatches(html).toList();

    // Labels and anchors are interleaved in the DOM in the same order
    if (anchors.length != labels.length) return null;

    final paddedSeason = season.toString().padLeft(2, '0');
    final paddedEpisode = episode.toString().padLeft(2, '0');

    for (int i = 0; i < anchors.length; i++) {
      final s = labels[i].group(1);
      final e = labels[i].group(2);
      if (s == paddedSeason && e == paddedEpisode) {
        return anchors[i].group(1);
      }
    }
    return null;
  }

  // ─── Comments Fetcher ──────────────────────────────────────────────────────

  Future<List<TvTimeComment>> _fetchCommentsByUuid(
    String entityUuid, {
    String sort = 'most_liked',
    int limit = 20,
  }) async {
    final innerUrl =
        '$_commentsBase/$entityUuid/comments?sort=$sort&limit=$limit';
    final encodedUrl = Uri.encodeComponent(innerUrl);
    final response = await _dio.get('$_sidecarBase$encodedUrl');

    final rawData = _extractDataList(response.data);
    
    // Parse the massive JSON list in a background isolate to prevent UI stutter
    return Isolate.run(() => _parseCommentsList(rawData));
  }

  static List<TvTimeComment> _parseCommentsList(List<dynamic> rawData) {
    return rawData
        .whereType<Map<String, dynamic>>()
        .map(TvTimeComment.fromJson)
        .toList();
  }

  // ─── JSON Helpers ──────────────────────────────────────────────────────────

  Map<String, dynamic>? _extractDataMap(dynamic body) {
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
      return body;
    }
    if (body is String) {
      try {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        return _extractDataMap(decoded);
      } catch (_) {}
    }
    return null;
  }

  List<dynamic> _extractDataList(dynamic body) {
    if (body is List) return body;
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is List) return data;
    }
    if (body is String) {
      try {
        final decoded = jsonDecode(body);
        return _extractDataList(decoded);
      } catch (_) {}
    }
    return [];
  }

  // ─── Constants ─────────────────────────────────────────────────────────────

  static const Map<String, String> _browserHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
  };
}
