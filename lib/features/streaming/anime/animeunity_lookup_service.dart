import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/streaming/anime/interfaces/anime_unity_mapping_provider.dart';
import 'package:cinemuse_app/features/streaming/anime/models/anime_unity_entry.dart';
import 'package:cinemuse_app/features/streaming/anime/models/kitsu_mapping.dart';
import 'package:dio/dio.dart';

const animeUnityBaseUrl = 'https://www.animeunity.so';

/// Finds the AnimeUnity entries of one anime season (REV-232).
///
/// No public service maps Kitsu / AniList IDs to AnimeUnity any more, so this
/// searches AnimeUnity by the season's Kitsu titles and keeps only the results
/// whose `anilist_id` is the mapping's AniList ID. A title match alone is never
/// trusted: a wrong season would play the wrong episode.
class AnimeUnityLookupService implements AnimeUnityMappingProvider {
  static const String _logTag = 'AnimeUnityLookupService';
  static const _kitsuAnimeUrl = 'https://kitsu.io/api/edge/anime';

  final Dio _dio;

  AnimeUnityLookupService(this._dio);

  @override
  Future<List<AnimeUnityEntry>> getAnimeUnityIds(KitsuMapping mapping) async {
    final anilistId = mapping.anilistId;
    if (anilistId == null) return [];

    try {
      final titles = await _fetchKitsuTitles(mapping.kitsuId);
      if (titles.isEmpty) return [];

      final session = await _openSession();
      // Livesearch returns at most 8 results, so the exact season title is
      // tried first and the others only when it finds nothing.
      for (final title in titles) {
        final entries = await _search(session, title, anilistId);
        if (entries.isNotEmpty) {
          AppLogger.debug(
            _logTag,
            'Kitsu ${mapping.kitsuId} (AniList $anilistId) -> '
            '${entries.map((e) => e.id).join(', ')}',
          );
          return entries;
        }
      }
      return [];
    } on DioException catch (e, st) {
      throw _failureFromDio(e, st);
    }
  }

  /// The Kitsu titles of [kitsuId], romaji first (AnimeUnity uses it).
  Future<List<String>> _fetchKitsuTitles(String kitsuId) async {
    final res = await _dio.get(
      '$_kitsuAnimeUrl/${Uri.encodeComponent(kitsuId)}',
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

  /// Loads the home page for the CSRF token and session cookies that
  /// livesearch requires (it answers 419 without them).
  Future<_AnimeUnitySession> _openSession() async {
    final res = await _dio.get<String>(
      '$animeUnityBaseUrl/',
      options: Options(responseType: ResponseType.plain),
    );
    final token = RegExp(
      r'''name="csrf-token"\s+content="([^"]+)"''',
    ).firstMatch(res.data ?? '')?.group(1);
    if (token == null) {
      throw const StreamingFailure('AnimeUnity CSRF token not found');
    }

    final cookies = (res.headers.map['set-cookie'] ?? const <String>[])
        .map((c) => c.split(';').first.trim())
        .where((c) => c.isNotEmpty)
        .join('; ');
    return _AnimeUnitySession(token: token, cookies: cookies);
  }

  Future<List<AnimeUnityEntry>> _search(
    _AnimeUnitySession session,
    String title,
    int anilistId,
  ) async {
    final res = await _dio.post(
      '$animeUnityBaseUrl/livesearch',
      data: {'title': title},
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'X-CSRF-TOKEN': session.token,
          'X-Requested-With': 'XMLHttpRequest',
          'Referer': '$animeUnityBaseUrl/',
          if (session.cookies.isNotEmpty) 'Cookie': session.cookies,
        },
      ),
    );
    return parseLiveSearch(res.data, anilistId);
  }

  /// Keeps the livesearch records of [anilistId] (usually the subbed and the
  /// Italian dub entry). Public for tests.
  static List<AnimeUnityEntry> parseLiveSearch(Object? data, int anilistId) {
    final records = data is Map ? data['records'] : null;
    if (records is! List) return [];

    final entries = <AnimeUnityEntry>[];
    for (final record in records.whereType<Map>()) {
      final id = record['id'];
      if (id is! int || record['anilist_id'] != anilistId) continue;
      final slug = record['slug']?.toString() ?? '';
      entries.add(AnimeUnityEntry(id: id, path: '/anime/$id-$slug'));
    }
    return entries;
  }

  AppFailure _failureFromDio(DioException e, StackTrace st) {
    final status = e.response?.statusCode;
    if (status == null) {
      return NetworkFailure(
        'AnimeUnity lookup: no answer',
        cause: e,
        stackTrace: st,
      );
    }
    return ServerFailure(
      'AnimeUnity lookup failed',
      statusCode: status,
      cause: e,
      stackTrace: st,
    );
  }
}

class _AnimeUnitySession {
  final String token;
  final String cookies;

  _AnimeUnitySession({required this.token, required this.cookies});
}
