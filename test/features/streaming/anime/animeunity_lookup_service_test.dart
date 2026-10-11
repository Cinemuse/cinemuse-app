import 'package:cinemuse_app/features/streaming/anime/animeunity_lookup_service.dart';
import 'package:cinemuse_app/features/streaming/anime/models/kitsu_mapping.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

Response<T> _response<T>(T data, {Map<String, List<String>>? headers}) =>
    Response<T>(
      requestOptions: RequestOptions(),
      statusCode: 200,
      data: data,
      headers: Headers.fromMap(headers ?? {}),
    );

Map<String, dynamic> _record(int id, String slug, int anilistId) => {
  'id': id,
  'title': slug,
  'slug': slug,
  'anilist_id': anilistId,
};

// Fire Force S3 (Kitsu 46119, AniList 149118): Part 2 has its own AniList ID.
final _fireForceRecords = {
  'records': [
    _record(6400, 'fire-force-3', 149118),
    _record(6401, 'fire-force-3-ita', 149118),
    _record(7216, 'fire-force-3-part-2', 179062),
    _record(7217, 'fire-force-3-part-2-ita', 179062),
  ],
};

void main() {
  late MockDio dio;
  late AnimeUnityLookupService service;

  setUp(() {
    dio = MockDio();
    service = AnimeUnityLookupService(dio);
  });

  group('parseLiveSearch', () {
    test('keeps only the records of the AniList ID', () {
      final entries = AnimeUnityLookupService.parseLiveSearch(
        _fireForceRecords,
        149118,
      );

      expect(entries.map((e) => e.id), [6400, 6401]);
      expect(entries.last.path, '/anime/6401-fire-force-3-ita');
    });

    test('returns nothing when no record has the AniList ID', () {
      expect(
        AnimeUnityLookupService.parseLiveSearch(_fireForceRecords, 1),
        isEmpty,
      );
      expect(AnimeUnityLookupService.parseLiveSearch('<html>', 1), isEmpty);
    });
  });

  group('getAnimeUnityIds', () {
    void stubKitsuAndHome() {
      when(
        () => dio.get(
          'https://kitsu.io/api/edge/anime/46119',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => _response({
          'data': {
            'attributes': {
              'canonicalTitle': 'Enen no Shouboutai: San no Shou',
              'titles': {
                'en': 'Fire Force Season 3',
                'en_jp': 'Enen no Shouboutai: San no Shou',
              },
            },
          },
        }),
      );
      when(
        () => dio.get<String>(
          '$animeUnityBaseUrl/',
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => _response(
          '<meta name="csrf-token" content="tok123">',
          headers: {
            'set-cookie': [
              'XSRF-TOKEN=abc; path=/',
              'animeunity_session=xyz; path=/; httponly',
            ],
          },
        ),
      );
    }

    test('without an AniList ID it never guesses', () async {
      final entries = await service.getAnimeUnityIds(
        KitsuMapping(kitsuId: '46119', absoluteEpisode: 10),
      );

      expect(entries, isEmpty);
      verifyZeroInteractions(dio);
    });

    test('searches the Kitsu titles and matches on the AniList ID', () async {
      stubKitsuAndHome();
      // The romaji title only finds other anime; the English one finds it.
      when(
        () => dio.post(
          '$animeUnityBaseUrl/livesearch',
          data: {'title': 'Enen no Shouboutai: San no Shou'},
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => _response({
          'records': [_record(7216, 'fire-force-3-part-2', 179062)],
        }),
      );
      when(
        () => dio.post(
          '$animeUnityBaseUrl/livesearch',
          data: {'title': 'Fire Force Season 3'},
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => _response(_fireForceRecords));

      final entries = await service.getAnimeUnityIds(
        KitsuMapping(kitsuId: '46119', absoluteEpisode: 10, anilistId: 149118),
      );

      expect(entries.map((e) => e.id), [6400, 6401]);
      final options =
          verify(
                () => dio.post(
                  '$animeUnityBaseUrl/livesearch',
                  data: {'title': 'Fire Force Season 3'},
                  options: captureAny(named: 'options'),
                ),
              ).captured.single
              as Options;
      expect(options.headers?['X-CSRF-TOKEN'], 'tok123');
      expect(
        options.headers?['Cookie'],
        'XSRF-TOKEN=abc; animeunity_session=xyz',
      );
    });

    test('a network error is thrown, not turned into "not found"', () async {
      when(
        () => dio.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.connectionError,
        ),
      );

      expect(
        () => service.getAnimeUnityIds(
          KitsuMapping(kitsuId: '46119', anilistId: 149118),
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
