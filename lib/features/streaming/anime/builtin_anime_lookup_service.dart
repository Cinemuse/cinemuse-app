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

      // The exact season title is tried first and the others only when it
      // finds nothing. Kitsu and the site often number a season differently
      // ("Edgerunners II" against "Edgerunners 2"), so last come the titles
      // without their season words; the AniList ID still picks the right
      // season among the results.
      var siteAddress = listed;
      var first = true;
      for (final title in [...titles, ...withoutSeasonWords(titles)]) {
        final search = await _search(siteAddress, title, anilistId);
        // The first search tells where the site answers from today.
        if (first) siteAddress = search.siteAddress;
        first = false;
        if (search.entries.isNotEmpty) {
          AppLogger.debug(
            _logTag,
            'Kitsu $kitsuId (AniList $anilistId) -> '
            '${search.entries.map((e) => e.id).join(', ')}',
          );
          return search;
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

  /// How many pages of results (30 each) one title looks through: a long
  /// franchise has dozens of entries, and the right season isn't always on
  /// the first page.
  static const maxPages = 3;

  /// Searches the site's archive for [title] at [siteAddress], keeping the
  /// results of [anilistId]. The answer's address is where the site answered
  /// from, followed if it moved.
  Future<BuiltInAnimeEntries> _search(
    String siteAddress,
    String title,
    int anilistId,
  ) async {
    var address = siteAddress;
    for (var page = 1; page <= maxPages; page++) {
      final res = await _dio.get(
        '$address/api/archive',
        queryParameters: {'query': title, 'page': page},
        options: Options(headers: {'Accept': 'application/json'}),
      );
      if (page == 1) address = addressAfterForward(siteAddress, res);
      final entries = parseArchive(res.data, anilistId);
      if (entries.isNotEmpty || !hasMorePages(res.data)) {
        return BuiltInAnimeEntries(siteAddress: address, entries: entries);
      }
    }
    return BuiltInAnimeEntries(siteAddress: address, entries: const []);
  }

  /// The archive's results of [anilistId] (one entry, which holds both the
  /// subbed and the Italian dub videos). Public for tests and the daily check.
  static List<BuiltInAnimeEntry> parseArchive(Object? data, int anilistId) {
    final results = data is Map ? data['data'] : null;
    if (results is! List) return [];

    final entries = <BuiltInAnimeEntry>[];
    for (final anime in results.whereType<Map>()) {
      final id = anime['id'];
      if (id is! int || anime['anilist_id'] != anilistId) continue;
      final slug = anime['slug']?.toString() ?? '';
      entries.add(BuiltInAnimeEntry(id: id, path: '/anime/$id-$slug'));
    }
    return entries;
  }

  /// Whether the archive has another page of results after [data]'s.
  static bool hasMorePages(Object? data) {
    if (data is! Map) return false;
    final current = data['current_page'];
    final last = data['last_page'];
    return current is int && last is int && current < last;
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
