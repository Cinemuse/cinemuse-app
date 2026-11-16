import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/features/streaming/anime/anime_mapping_service.dart';
import 'package:cinemuse_app/features/streaming/anime/anime_mapping_sync_service.dart';
import 'package:cinemuse_app/features/streaming/anime/models/anime_match.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

const _url = 'https://project.test/functions/v1/anime-mapping';

/// The cases the server's tests run too, so the app's copy picks the same.
final _known =
    jsonDecode(
          File(
            'supabase/functions/anime-mapping/known_cases.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

/// [lookup] in the server's answer format, to compare with the known cases.
Map<String, dynamic> _asAnswer(AnimeLookup lookup) {
  final match = lookup.match;
  return {
    'is_anime': lookup.isAnime,
    'match': match == null
        ? null
        : {
            'anilist_id': match.anilistId,
            'anidb_id': ?match.anidbId,
            'kitsu_id': ?(match.kitsuId == null
                ? null
                : int.parse(match.kitsuId!)),
            'episode': ?match.absoluteEpisode,
          },
  };
}

void main() {
  late _MockDio dio;
  late AppDatabase db;
  late String? token;
  late AnimeMappingService service;

  setUpAll(() => registerFallbackValue(Options()));

  setUp(() {
    dio = _MockDio();
    db = AppDatabase(NativeDatabase.memory());
    token = 'user-token';
    service = AnimeMappingService(
      dio,
      db,
      url: _url,
      apiKey: 'publishable',
      accessToken: () => token,
      serverTimeout: const Duration(milliseconds: 50),
    );
  });

  tearDown(() => db.close());

  /// Fills the copy with a known fixture's lines, as the download stores
  /// them.
  Future<void> fillCopy(String fixture) async {
    final rows = (_known['fixtures'] as Map<String, dynamic>)[fixture]['rows'];
    await db.replaceAnimeExternalMappings(
      AnimeMappingSyncService.parseRows(jsonEncode({'rows': rows})),
    );
  }

  void serverAnswers(Future<Response<Map<String, dynamic>>> Function() a) {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) => a());
  }

  void serverUnreachable() => serverAnswers(
    () async => throw DioException(
      requestOptions: RequestOptions(path: _url),
      type: DioExceptionType.connectionError,
    ),
  );

  Response<Map<String, dynamic>> answer(Map<String, dynamic> body) => Response(
    requestOptions: RequestOptions(path: _url),
    statusCode: 200,
    data: body,
  );

  group('offline, the copy answers the known cases like the server', () {
    for (final c in (_known['cases'] as List).cast<Map<String, dynamic>>()) {
      test(c['name'], () async {
        serverUnreachable();
        await fillCopy(c['fixture'] as String);
        final ask = c['ask'] as Map<String, dynamic>;

        final lookup = await service.lookUp(
          tmdbId: ask['tmdb_id'] as int,
          type: ask['type'] as String,
          season: ask['season'] as int?,
          episode: ask['episode'] as int?,
        );

        expect(_asAnswer(lookup), c['answer']);
      });
    }
  });

  test('the server answers first, asked as the user', () async {
    serverAnswers(
      () async => answer({
        'is_anime': true,
        'match': {'anilist_id': 142853, 'kitsu_id': 45607, 'episode': 13},
      }),
    );

    final lookup = await service.lookUp(
      tmdbId: 105009,
      type: 'tv',
      season: 1,
      episode: 37,
    );

    expect(lookup.isAnime, isTrue);
    expect(lookup.match?.anilistId, 142853);
    expect(lookup.match?.kitsuId, '45607');
    expect(lookup.match?.absoluteEpisode, 13);
    final captured = verify(
      () => dio.get<Map<String, dynamic>>(
        _url,
        queryParameters: captureAny(named: 'queryParameters'),
        options: captureAny(named: 'options'),
      ),
    ).captured;
    expect(captured[0], {
      'tmdb_id': 105009,
      'type': 'tv',
      'season': 1,
      'episode': 37,
    });
    expect((captured[1] as Options).headers, {
      'apikey': 'publishable',
      'Authorization': 'Bearer user-token',
    });
  });

  test('a film is asked without season or episode', () async {
    serverAnswers(
      () async => answer({
        'is_anime': true,
        'match': {'anilist_id': 5},
      }),
    );

    final lookup = await service.lookUp(tmdbId: 77, type: 'movie');

    expect(lookup.match?.anilistId, 5);
    expect(lookup.match?.kitsuId, isNull);
    expect(
      verify(
        () => dio.get<Map<String, dynamic>>(
          _url,
          queryParameters: captureAny(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).captured.single,
      {'tmdb_id': 77, 'type': 'movie'},
    );
  });

  test('the server saying "no match" wins over the copy', () async {
    await fillCopy('tokyo-revengers');
    serverAnswers(() async => answer({'is_anime': true, 'match': null}));

    final lookup = await service.lookUp(
      tmdbId: 105009,
      type: 'tv',
      season: 1,
      episode: 37,
    );

    expect(lookup.isAnime, isTrue);
    expect(lookup.match, isNull);
  });

  test('a slow server: the copy answers', () async {
    await fillCopy('tokyo-revengers');
    serverAnswers(() => Completer<Response<Map<String, dynamic>>>().future);

    final lookup = await service.lookUp(
      tmdbId: 105009,
      type: 'tv',
      season: 1,
      episode: 37,
    );

    expect(lookup.match?.anilistId, 142853);
    expect(lookup.match?.absoluteEpisode, 13);
  });

  test('an odd answer: the copy answers', () async {
    await fillCopy('tokyo-revengers');
    serverAnswers(() async => answer({'rows': []}));

    final lookup = await service.lookUp(
      tmdbId: 105009,
      type: 'tv',
      season: 1,
      episode: 1,
    );

    expect(lookup.match?.anilistId, 120120);
  });

  test('signed out: the server is not asked, the copy answers', () async {
    token = null;
    await fillCopy('tokyo-revengers');

    final lookup = await service.lookUp(
      tmdbId: 105009,
      type: 'tv',
      season: 1,
      episode: 51,
    );

    expect(lookup.match?.absoluteEpisode, 1);
    verifyNever(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
      ),
    );
  });
}
