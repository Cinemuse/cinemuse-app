import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/features/streaming/anime/anime_mapping_sync_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDio extends Mock implements Dio {}

class _MockAppDatabase extends Mock implements AppDatabase {}

const _lastSyncKey = 'last_anime_mapping_sync_server';
const _url = 'https://project.test/functions/v1/anime-mapping';

// The function's answer: Tokyo Revengers (TMDB 105009) puts four anime in
// TMDB season 1, one after the other; anime 5 is a film.
const _rowsBody = '''
{"rows": [
  {"anilist_id": 120120, "anidb_id": 15601, "kitsu_id": 43321,
   "tmdb_show_id": 105009, "tvdb_id": 393478,
   "tmdb_episodes": [{"season": 1, "first": 1, "last": 24, "anime_first": 1}],
   "placed_by": "anibridge", "tmdb_ranges": {"s1": "e1-e24"}},
  {"anilist_id": 142853, "tmdb_show_id": 105009,
   "tmdb_episodes": [{"season": 1, "first": 25, "last": 37, "anime_first": 1}]},
  {"anilist_id": 163329, "tmdb_show_id": 105009,
   "tmdb_episodes": [{"season": 1, "first": 38, "last": 50, "anime_first": 1}]},
  {"anilist_id": 178083, "tmdb_show_id": 105009,
   "tmdb_episodes": [{"season": 1, "first": 51, "anime_first": 1}]},
  {"anilist_id": 5, "tmdb_movie_id": 77}
]}
''';

void main() {
  late _MockDio dio;
  late _MockAppDatabase db;
  late String? token;
  late AnimeMappingSyncService service;

  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(<AnimeExternalMappingsCompanion>[]);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dio = _MockDio();
    db = _MockAppDatabase();
    token = 'user-token';
    service = AnimeMappingSyncService(
      dio,
      db,
      url: _url,
      apiKey: 'publishable',
      accessToken: () => token,
    );
    when(() => db.getAnimeExternalMappingsCount()).thenAnswer((_) async => 0);
    when(() => db.replaceAnimeExternalMappings(any())).thenAnswer((_) async {});
  });

  void answerWith(String body) {
    when(
      () => dio.get<String>(any(), options: any(named: 'options')),
    ).thenAnswer(
      (inv) async => Response<String>(
        requestOptions: RequestOptions(path: inv.positionalArguments.first),
        statusCode: 200,
        data: body,
      ),
    );
  }

  List<AnimeExternalMappingsCompanion> storedRows() =>
      verify(
            () => db.replaceAnimeExternalMappings(captureAny()),
          ).captured.single
          as List<AnimeExternalMappingsCompanion>;

  test('a failed sync does not save the sync time (REV-34)', () async {
    when(
      () => dio.get<String>(any(), options: any(named: 'options')),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: _url),
        type: DioExceptionType.connectionError,
      ),
    );

    await service.checkAndSync();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_lastSyncKey), isNull);
    verifyNever(() => db.replaceAnimeExternalMappings(any()));
  });

  test('a good sync asks the function as the user and stores the rows '
      '(REV-316)', () async {
    answerWith(_rowsBody);

    await service.checkAndSync();

    final options =
        verify(
              () =>
                  dio.get<String>(_url, options: captureAny(named: 'options')),
            ).captured.single
            as Options;
    expect(options.headers, {
      'apikey': 'publishable',
      'Authorization': 'Bearer user-token',
    });
    expect(storedRows().map((r) => r.anilistId.value), [
      120120,
      142853,
      163329,
      178083,
      5,
    ]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_lastSyncKey), isNotNull);
  });

  test('signed out: no download, the old list stays', () async {
    token = null;

    await service.checkAndSync();

    verifyNever(() => dio.get<String>(any(), options: any(named: 'options')));
    verifyNever(() => db.replaceAnimeExternalMappings(any()));
  });

  test('an empty answer keeps the old list', () async {
    answerWith('{"rows": []}');

    await service.checkAndSync();

    verifyNever(() => db.replaceAnimeExternalMappings(any()));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_lastSyncKey), isNull);
  });

  test('the list syncs at once after the move to the server', () async {
    SharedPreferences.setMockInitialValues({
      'last_anime_mapping_sync_fribb': DateTime.now().toIso8601String(),
    });
    when(() => db.getAnimeExternalMappingsCount()).thenAnswer((_) async => 9);
    answerWith(_rowsBody);

    await service.checkAndSync();

    storedRows();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('last_anime_mapping_sync_fribb'), isFalse);
  });

  test('parseRows keeps the ids and the exact episodes', () {
    final rows = AnimeMappingSyncService.parseRows(_rowsBody);

    final first = rows.first;
    expect(first.anilistId.value, 120120);
    expect(first.anidbId.value, 15601);
    expect(first.kitsuId.value, 43321);
    expect(first.tmdbShowId.value, 105009);
    expect(first.tmdbMovieId.value, isNull);
    expect(
      first.tmdbEpisodes.value,
      '[{"season":1,"first":1,"last":24,"anime_first":1}]',
    );
    expect(rows[1].kitsuId.value, isNull);
    expect(
      rows[3].tmdbEpisodes.value,
      '[{"season":1,"first":51,"anime_first":1}]',
    );
    expect(rows.last.tmdbMovieId.value, 77);
    expect(rows.last.tmdbEpisodes.value, isNull);
  });

  test('parseRows skips rows without an AniList id and odd answers', () {
    expect(
      AnimeMappingSyncService.parseRows(
        '{"rows": [{"tmdb_show_id": 1}, "junk", {"anilist_id": 2}]}',
      ).map((r) => r.anilistId.value),
      [2],
    );
    expect(AnimeMappingSyncService.parseRows('[]'), isEmpty);
    expect(AnimeMappingSyncService.parseRows('{"rows": 3}'), isEmpty);
  });
}
