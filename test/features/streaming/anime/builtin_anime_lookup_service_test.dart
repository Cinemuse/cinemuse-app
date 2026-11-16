import 'package:cinemuse_app/core/data/server_addresses_model.dart';
import 'package:cinemuse_app/features/streaming/anime/builtin_anime_lookup_service.dart';
import 'package:cinemuse_app/features/streaming/anime/models/anime_match.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

/// Not the site's real address: the lookup must use the server list's.
const _siteAddress = 'https://anime.example';

ServerAddressesLoader _sitesWith(String? animeSite, {String? kitsu}) =>
    () async => ServerAddresses.fromRows([
      if (animeSite != null)
        {'key': ServerAddress.animeSite.key, 'address': animeSite},
      if (kitsu != null) {'key': ServerAddress.kitsu.key, 'address': kitsu},
    ]);

Response<T> _response<T>(
  T data, {
  Map<String, List<String>>? headers,
  String? forwardedTo,
}) => Response<T>(
  requestOptions: RequestOptions(),
  statusCode: 200,
  data: data,
  headers: Headers.fromMap(headers ?? {}),
  redirects: [
    if (forwardedTo != null) RedirectRecord(302, 'GET', Uri.parse(forwardedTo)),
  ],
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
  late BuiltInAnimeLookupService service;

  setUp(() {
    dio = MockDio();
    service = BuiltInAnimeLookupService(dio, _sitesWith(_siteAddress));
  });

  group('parseLiveSearch', () {
    test('keeps only the records of the AniList ID', () {
      final entries = BuiltInAnimeLookupService.parseLiveSearch(
        _fireForceRecords,
        149118,
      );

      expect(entries.map((e) => e.id), [6400, 6401]);
      expect(entries.last.path, '/anime/6401-fire-force-3-ita');
    });

    test('returns nothing when no record has the AniList ID', () {
      expect(
        BuiltInAnimeLookupService.parseLiveSearch(_fireForceRecords, 1),
        isEmpty,
      );
      expect(BuiltInAnimeLookupService.parseLiveSearch('<html>', 1), isEmpty);
    });
  });

  group('withoutSeasonWords', () {
    test('takes the season words off the end, in any form', () {
      expect(
        BuiltInAnimeLookupService.withoutSeasonWords([
          'Cyberpunk: Edgerunners II',
          'The Elusive Samurai Season 2',
          'Nige Jouzu no Wakagimi 2nd Season',
          'World Fool News Part II',
          'Thunderbolt Fantasy: Sword Seekers 3',
        ]),
        [
          'Cyberpunk: Edgerunners',
          'The Elusive Samurai',
          'Nige Jouzu no Wakagimi',
          'World Fool News',
          'Thunderbolt Fantasy: Sword Seekers',
        ],
      );
    });

    test('one by one, from the most precise', () {
      expect(
        BuiltInAnimeLookupService.withoutSeasonWords([
          'Tensei shitara Slime Datta Ken 2nd Season Part 2',
        ]),
        [
          'Tensei shitara Slime Datta Ken 2nd Season',
          'Tensei shitara Slime Datta Ken',
        ],
      );
    });

    test('leaves out titles already searched, whatever their case', () {
      expect(
        BuiltInAnimeLookupService.withoutSeasonWords([
          'Cyberpunk: Edgerunners II',
          'CYBERPUNK: EDGERUNNERS II',
          'Cyberpunk: Edgerunners',
        ]),
        isEmpty,
      );
    });

    test('titles with no season words give nothing', () {
      expect(
        BuiltInAnimeLookupService.withoutSeasonWords([
          'Spy x Family',
          'Kaiji',
          'Dr. STONE: NEW WORLD',
          '86',
        ]),
        isEmpty,
      );
    });
  });

  group('findEntries', () {
    // With no Kitsu row in the list, the app's own copy of its address.
    void stubKitsuAndHome({String kitsu = 'https://kitsu.app/api/edge'}) {
      when(
        () => dio.get(
          '$kitsu/anime/46119',
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
        () => dio.get<String>('$_siteAddress/', options: any(named: 'options')),
      ).thenAnswer(
        (_) async => _response(
          '<meta name="csrf-token" content="tok123">',
          headers: {
            'set-cookie': [
              'XSRF-TOKEN=abc; path=/',
              'site_session=xyz; path=/; httponly',
            ],
          },
        ),
      );
    }

    test('no address in the list: finds nothing, asks no site', () async {
      service = BuiltInAnimeLookupService(dio, _sitesWith(null));

      final found = await service.findEntries(
        AnimeMatch(kitsuId: '46119', absoluteEpisode: 10, anilistId: 149118),
      );

      expect(found, isNull);
      verifyZeroInteractions(dio);
    });

    test("Kitsu's address comes from the server's list", () async {
      service = BuiltInAnimeLookupService(
        dio,
        _sitesWith(_siteAddress, kitsu: 'https://kitsu.example/api/edge/'),
      );
      stubKitsuAndHome(kitsu: 'https://kitsu.example/api/edge');
      when(
        () => dio.post(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => _response(_fireForceRecords));

      final found = await service.findEntries(
        AnimeMatch(kitsuId: '46119', absoluteEpisode: 10, anilistId: 149118),
      );

      expect(found!.entries.map((e) => e.id), [6400, 6401]);
    });

    test('without a Kitsu id it has no titles to search by', () async {
      final found = await service.findEntries(
        AnimeMatch(anilistId: 149118, absoluteEpisode: 10),
      );

      expect(found, isNull);
      verifyZeroInteractions(dio);
    });

    test('a site that moved: it searches where the home page landed, '
        'and says so', () async {
      stubKitsuAndHome();
      when(
        () => dio.get<String>('$_siteAddress/', options: any(named: 'options')),
      ).thenAnswer(
        (_) async => _response(
          '<meta name="csrf-token" content="tok123">',
          forwardedTo: 'https://anime-new.example/',
        ),
      );
      when(
        () => dio.post(
          'https://anime-new.example/livesearch',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => _response(_fireForceRecords));

      final found = await service.findEntries(
        AnimeMatch(kitsuId: '46119', absoluteEpisode: 10, anilistId: 149118),
      );

      expect(found!.siteAddress, 'https://anime-new.example');
      expect(found.entries.map((e) => e.id), [6400, 6401]);
      final options =
          verify(
                () => dio.post(
                  'https://anime-new.example/livesearch',
                  data: any(named: 'data'),
                  options: captureAny(named: 'options'),
                ),
              ).captured.single
              as Options;
      expect(options.headers?['Referer'], 'https://anime-new.example/');
    });

    test('searches the Kitsu titles and matches on the AniList ID', () async {
      stubKitsuAndHome();
      // The romaji title only finds other anime; the English one finds it.
      when(
        () => dio.post(
          '$_siteAddress/livesearch',
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
          '$_siteAddress/livesearch',
          data: {'title': 'Fire Force Season 3'},
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => _response(_fireForceRecords));

      final found = await service.findEntries(
        AnimeMatch(kitsuId: '46119', absoluteEpisode: 10, anilistId: 149118),
      );

      expect(found!.siteAddress, _siteAddress);
      expect(found.entries.map((e) => e.id), [6400, 6401]);
      final options =
          verify(
                () => dio.post(
                  '$_siteAddress/livesearch',
                  data: {'title': 'Fire Force Season 3'},
                  options: captureAny(named: 'options'),
                ),
              ).captured.single
              as Options;
      expect(options.headers?['X-CSRF-TOKEN'], 'tok123');
      expect(options.headers?['Cookie'], 'XSRF-TOKEN=abc; site_session=xyz');
    });

    test('a season numbered otherwise on the site: found by the title '
        'without its season words, still matched on the AniList ID', () async {
      stubKitsuAndHome();
      // Cyberpunk: Edgerunners 2 (Kitsu 50016, AniList 195539): Kitsu says
      // "II", the site says "2", so only the shorter title finds it, along
      // with the first season.
      when(
        () => dio.get(
          'https://kitsu.app/api/edge/anime/50016',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => _response({
          'data': {
            'attributes': {
              'canonicalTitle': 'Cyberpunk: Edgerunners II',
              'titles': {
                'en': 'CYBERPUNK: EDGERUNNERS II',
                'en_jp': 'Cyberpunk: Edgerunners II',
              },
            },
          },
        }),
      );
      when(
        () => dio.post(
          '$_siteAddress/livesearch',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => _response({'records': []}));
      when(
        () => dio.post(
          '$_siteAddress/livesearch',
          data: {'title': 'Cyberpunk: Edgerunners'},
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => _response({
          'records': [
            _record(4017, 'cyberpunk-edgerunners', 120377),
            _record(4016, 'cyberpunk-edgerunners-ita', 120377),
            _record(7803, 'cyberpunk-edgerunners-2', 195539),
            _record(7869, 'cyberpunk-edgerunners-2-ita', 195539),
          ],
        }),
      );

      final found = await service.findEntries(
        AnimeMatch(kitsuId: '50016', absoluteEpisode: 1, anilistId: 195539),
      );

      expect(found!.entries.map((e) => e.id), [7803, 7869]);
      final searched = verify(
        () => dio.post(
          '$_siteAddress/livesearch',
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(searched, [
        {'title': 'Cyberpunk: Edgerunners II'},
        {'title': 'CYBERPUNK: EDGERUNNERS II'},
        {'title': 'Cyberpunk: Edgerunners'},
      ]);
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
        () => service.findEntries(
          AnimeMatch(kitsuId: '46119', anilistId: 149118),
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
