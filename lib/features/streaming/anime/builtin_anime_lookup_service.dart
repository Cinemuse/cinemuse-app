import 'package:cinemuse_app/core/data/server_addresses_model.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/streaming/anime/interfaces/builtin_anime_lookup.dart';
import 'package:cinemuse_app/features/streaming/anime/models/builtin_anime_entry.dart';
import 'package:cinemuse_app/features/streaming/anime/models/anime_match.dart';
import 'package:cinemuse_app/features/streaming/sources/site_forward.dart';
import 'package:dio/dio.dart';

/// Finds the built-in anime site's entries of one anime season (REV-232).
///
/// No public service maps Kitsu / AniList IDs to the site, so this searches
/// the site by the season's Kitsu titles and keeps only the results
/// whose `anilist_id` is the mapping's AniList ID. A title match alone is never
/// trusted: a wrong season would play the wrong episode.
class BuiltInAnimeLookupService implements BuiltInAnimeLookup {
  static const String _logTag = 'BuiltInAnimeLookupService';

  final Dio _dio;

  /// The site's and Kitsu's addresses come from the server's list (STR-08).
  final ServerAddressesLoader _loadAddresses;

  BuiltInAnimeLookupService(this._dio, this._loadAddresses);

  @override
  Future<BuiltInAnimeEntries?> findEntries(AnimeMatch mapping) async {
    final anilistId = mapping.anilistId;
    // The titles to search by come from Kitsu.
    final kitsuId = mapping.kitsuId;
    if (kitsuId == null) return null;

    final addresses = await _loadAddresses();
    final listed = addresses.baseUrl(ServerAddress.animeSite);
    if (listed == null) {
      AppLogger.warn(_logTag, 'No anime site address in the site list');
      return null;
    }

    try {
      final titles = await _fetchKitsuTitles(
        addresses.baseUrl(ServerAddress.kitsu)!,
        kitsuId,
      );
      if (titles.isEmpty) return null;

      final session = await _openSession(listed);
      // Livesearch returns at most 8 results, so the exact season title is
      // tried first and the others only when it finds nothing. Kitsu and the
      // site often number a season differently ("Edgerunners II" against
      // "Edgerunners 2"), so last come the titles without their season
      // words; the AniList ID still picks the right season among the results.
      for (final title in [...titles, ...withoutSeasonWords(titles)]) {
        final entries = await _search(session, title, anilistId);
        if (entries.isNotEmpty) {
          AppLogger.debug(
            _logTag,
            'Kitsu $kitsuId (AniList $anilistId) -> '
            '${entries.map((e) => e.id).join(', ')}',
          );
          return BuiltInAnimeEntries(
            siteAddress: session.siteAddress,
            entries: entries,
          );
        }
      }
      return null;
    } on DioException catch (e, st) {
      throw _failureFromDio(e, st);
    }
  }

  /// The Kitsu titles of [kitsuId], romaji first (the site uses it).
  Future<List<String>> _fetchKitsuTitles(
    String kitsuUrl,
    String kitsuId,
  ) async {
    final res = await _dio.get(
      '$kitsuUrl/anime/${Uri.encodeComponent(kitsuId)}',
      queryParameters: {'fields[anime]': 'canonicalTitle,titles'},
    );
    final attributes = res.data?['data']?['attributes'];
    if (attributes is! Map) return [];

    final titles = attributes['titles'];
    final candidates = [
      if (titles is Map) titles['en_jp'],
      attributes['canonicalTitle'],
      if (titles is Map) titles['en'],
    ];
    return candidates
        .whereType<String>()
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
  }

  /// A season's words at the end of a title: "II", "2", "Season 2",
  /// "2nd Season", "Part 2", "Cour 2".
  static final _seasonWords = RegExp(
    r'[\s:\-–]+(?:(?:season|part|cour)\s*(?:\d+|[ivx]+)'
    r'|\d+(?:st|nd|rd|th)\s+(?:season|part|cour)|[ivx]+|\d+)$',
    caseSensitive: false,
  );

  static final _letter = RegExp(r'\p{L}', unicode: true);

  /// The [titles] with their season words taken off the end, one by one
  /// ("Slime 2nd Season Part 2" → "Slime 2nd Season" → "Slime"), leaving out
  /// any already in [titles] or with no letters left. Public for tests.
  static List<String> withoutSeasonWords(List<String> titles) {
    final seen = titles.map((t) => t.toLowerCase()).toSet();
    final shorter = <String>[];
    for (var title in titles) {
      while (true) {
        final cut = title.replaceFirst(_seasonWords, '').trim();
        if (cut == title || !_letter.hasMatch(cut)) break;
        title = cut;
        if (seen.add(cut.toLowerCase())) shorter.add(cut);
      }
    }
    return shorter;
  }

  /// Loads the home page for the CSRF token and session cookies that
  /// livesearch requires (it answers 419 without them), and for the address
  /// the site answers from today.
  Future<_BuiltInAnimeSession> _openSession(String listed) async {
    final res = await _dio.get<String>(
      '$listed/',
      options: Options(responseType: ResponseType.plain),
    );
    final token = RegExp(
      r'''name="csrf-token"\s+content="([^"]+)"''',
    ).firstMatch(res.data ?? '')?.group(1);
    if (token == null) {
      throw const StreamingFailure('Anime site CSRF token not found');
    }

    final cookies = (res.headers.map['set-cookie'] ?? const <String>[])
        .map((c) => c.split(';').first.trim())
        .where((c) => c.isNotEmpty)
        .join('; ');
    return _BuiltInAnimeSession(
      siteAddress: addressAfterForward(listed, res),
      token: token,
      cookies: cookies,
    );
  }

  Future<List<BuiltInAnimeEntry>> _search(
    _BuiltInAnimeSession session,
    String title,
    int anilistId,
  ) async {
    final baseUrl = session.siteAddress;
    final res = await _dio.post(
      '$baseUrl/livesearch',
      data: {'title': title},
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'X-CSRF-TOKEN': session.token,
          'X-Requested-With': 'XMLHttpRequest',
          'Referer': '$baseUrl/',
          if (session.cookies.isNotEmpty) 'Cookie': session.cookies,
        },
      ),
    );
    return parseLiveSearch(res.data, anilistId);
  }

  /// Keeps the livesearch records of [anilistId] (usually the subbed and the
  /// Italian dub entry). Public for tests.
  static List<BuiltInAnimeEntry> parseLiveSearch(Object? data, int anilistId) {
    final records = data is Map ? data['records'] : null;
    if (records is! List) return [];

    final entries = <BuiltInAnimeEntry>[];
    for (final record in records.whereType<Map>()) {
      final id = record['id'];
      if (id is! int || record['anilist_id'] != anilistId) continue;
      final slug = record['slug']?.toString() ?? '';
      entries.add(BuiltInAnimeEntry(id: id, path: '/anime/$id-$slug'));
    }
    return entries;
  }

  AppFailure _failureFromDio(DioException e, StackTrace st) {
    final status = e.response?.statusCode;
    if (status == null) {
      return NetworkFailure(
        'Anime site lookup: no answer',
        cause: e,
        stackTrace: st,
      );
    }
    return ServerFailure(
      'Anime site lookup failed',
      statusCode: status,
      cause: e,
      stackTrace: st,
    );
  }
}

class _BuiltInAnimeSession {
  final String siteAddress;
  final String token;
  final String cookies;

  _BuiltInAnimeSession({
    required this.siteAddress,
    required this.token,
    required this.cookies,
  });
}
