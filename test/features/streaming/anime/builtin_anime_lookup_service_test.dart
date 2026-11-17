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

Map<String, dynamic> _anime(int id, String slug, int anilistId) => {
  'id': id,
  'title': slug,
  'slug': slug,
  'anilist_id': anilistId,
  'variants': [
    {'language': 'ita'},
    {'language': 'jpn'},
  ],
};

/// One page of the archive's results, as the site answers it.
Map<String, dynamic> _page(
  List<Map<String, dynamic>> results, {
  int page = 1,
  int lastPage = 1,
}) => {
  'current_page': page,
  'last_page': lastPage,
  'per_page': 30,
  'data': results,
};

// Fire Force S3 (Kitsu 46119, AniList 149118): Part 2 has its own AniList ID.
final _fireForceResults = _page([
  _anime(6400, 'fire-force-3', 149118),
  _anime(7216, 'fire-force-3-part-2', 179062),
]);

void main() {
  late MockDio dio;
  late BuiltInAnimeLookupService service;

  setUp(() {
    dio = MockDio();
    service = BuiltInAnimeLookupService(dio, _sitesWith(_siteAddress));
  });

  group('parseArchive', () {
    test('keeps only the results of the AniList ID', () {
      final entries = BuiltInAnimeLookupService.parseArchive(
        _fireForceResults,
        149118,
      );

      expect(entries.map((e) => e.id), [6400]);
      expect(entries.single.path, '/anime/6400-fire-force-3');
    });

    test('returns nothing when no result has the AniList ID', () {
      expect(
        BuiltInAnimeLookupService.parseArchive(_fireForceResults, 1),
        isEmpty,
      );
      expect(BuiltInAnimeLookupService.parseArchive('<html>', 1), isEmpty);
      // The old search's answer: its results were under `records`.
      expect(
        BuiltInAnimeLookupService.parseArchive({
          'records': [_anime(6400, 'fire-force-3', 149118)],
        }, 149118),
        isEmpty,
      );
    });
  });

  group('hasMorePages', () {
    test('only while the page is before the last', () {
      expect(
        BuiltInAnimeLookupService.hasMorePages(_page([], page: 1, lastPage: 3)),
        isTrue,
      );
      expect(
        BuiltInAnimeLookupService.hasMorePages(_page([], page: 3, lastPage: 3)),
        isFalse,
      );
      expect(BuiltInAnimeLookupService.hasMorePages('<html>'), isFalse);
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
    void stubKitsu({
      String kitsu = 'https://kitsu.app/api/edge',
      String kitsuId = '46119',
      String canonical = 'Enen no Shouboutai: San no Shou',
      String english = 'Fire Force Season 3',
    }) {
      when(
        () => dio.get(
          '$kitsu/anime/$kitsuId',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => _response({
          'data': {
            'attributes': {
              'canonicalTitle': canonical,
              'titles': {'en': english, 'en_jp': canonical},
            },
          },
        }),
      );
    }

    /// The archive's answer to [title] on [page] at [site].
    void stubArchive(
      Object answer, {
      String? title,
      int? page,
      String site = _siteAddress,
      String? forwardedTo,
    }) {
      when(
        () => dio.get(
          '$site/api/archive',
          queryParameters: title == null && page == null
              ? any(named: 'queryParameters')
              : {'query': title, 'page': page ?? 1},
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => _response(answer, forwardedTo: forwardedTo));
    }

    List<Object?> searched({String site = _siteAddress}) => verify(
      () => dio.get(
        '$site/api/archive',
        queryParameters: captureAny(named: 'queryParameters'),
        options: any(named: 'options'),
      ),
    ).captured;

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
      stubKitsu(kitsu: 'https://kitsu.example/api/edge');
      stubArchive(_fireForceResults);

      final found = await service.findEntries(
        AnimeMatch(kitsuId: '46119', absoluteEpisode: 10, anilistId: 149118),
      );

      expect(found!.entries.map((e) => e.id), [6400]);
    });

    test('without a Kitsu id it has no titles to search by', () async {
      final found = await service.findEntries(
        AnimeMatch(anilistId: 149118, absoluteEpisode: 10),
      );

      expect(found, isNull);
      verifyZeroInteractions(dio);
    });

    test('a site that moved: it searches on where the first search landed, '
        'and says so', () async {
      stubKitsu();
      // The romaji title lands on the new address and finds only Part 2.
      stubArchive(
        _page([_anime(7216, 'fire-force-3-part-2', 179062)]),
        title: 'Enen no Shouboutai: San no Shou',
        forwardedTo: 'https://anime-new.example/api/archive',
      );
      stubArchive(
        _fireForceResults,
        title: 'Fire Force Season 3',
        site: 'https://anime-new.example',
      );

      final found = await service.findEntries(
        AnimeMatch(kitsuId: '46119', absoluteEpisode: 10, anilistId: 149118),
      );

      expect(found!.siteAddress, 'https://anime-new.example');
      expect(found.entries.map((e) => e.id), [6400]);
      expect(searched(site: 'https://anime-new.example'), [
        {'query': 'Fire Force Season 3', 'page': 1},
      ]);
    });

    test('searches the Kitsu titles and matches on the AniList ID', () async {
      stubKitsu();
      // The romaji title only finds other anime; the English one finds it.
      stubArchive(
        _page([_anime(7216, 'fire-force-3-part-2', 179062)]),
        title: 'Enen no Shouboutai: San no Shou',
      );
      stubArchive(_fireForceResults, title: 'Fire Force Season 3');

      final found = await service.findEntries(
        AnimeMatch(kitsuId: '46119', absoluteEpisode: 10, anilistId: 149118),
      );

      expect(found!.siteAddress, _siteAddress);
      expect(found.entries.map((e) => e.id), [6400]);
      final [romaji, romajiOptions, english, _] = verify(
        () => dio.get(
          '$_siteAddress/api/archive',
          queryParameters: captureAny(named: 'queryParameters'),
          options: captureAny(named: 'options'),
        ),
      ).captured;
      expect(romaji, {'query': 'Enen no Shouboutai: San no Shou', 'page': 1});
      expect(english, {'query': 'Fire Force Season 3', 'page': 1});
      final options = romajiOptions as Options;
      expect(options.headers?['Accept'], 'application/json');
    });

    test('a long franchise: the season on a later page is found', () async {
      // One Piece has dozens of entries: the series is on page 2.
      stubKitsu(canonical: 'One Piece', english: 'One Piece');
      stubArchive(
        _page([_anime(5000, 'one-piece-film-red', 141902)], lastPage: 3),
        title: 'One Piece',
        page: 1,
      );
      stubArchive(
        _page([_anime(12, 'one-piece', 21)], page: 2, lastPage: 3),
        title: 'One Piece',
        page: 2,
      );

      final found = await service.findEntries(
        AnimeMatch(kitsuId: '46119', absoluteEpisode: 1, anilistId: 21),
      );

      expect(found!.entries.map((e) => e.id), [12]);
      expect(searched(), [
        {'query': 'One Piece', 'page': 1},
        {'query': 'One Piece', 'page': 2},
      ]);
    });

    test('looks through at most ${BuiltInAnimeLookupService.maxPages} '
        'pages of one title', () async {
      stubKitsu(canonical: 'One Piece', english: 'One Piece');
      stubArchive(_page([_anime(1, 'other', 1)], lastPage: 9));

      final found = await service.findEntries(
        AnimeMatch(kitsuId: '46119', absoluteEpisode: 1, anilistId: 21),
      );

      expect(found, isNull);
      expect(searched(), [
        for (var page = 1; page <= BuiltInAnimeLookupService.maxPages; page++)
          {'query': 'One Piece', 'page': page},
      ]);
    });

    test('a season numbered otherwise on the site: found by the title '
        'without its season words, still matched on the AniList ID', () async {
      // Cyberpunk: Edgerunners 2 (Kitsu 50016, AniList 195539): Kitsu says
      // "II", the site says "2", so only the shorter title finds it, along
      // with the first season.
      stubKitsu(
        kitsuId: '50016',
        canonical: 'Cyberpunk: Edgerunners II',
        english: 'CYBERPUNK: EDGERUNNERS II',
      );
      stubArchive(_page([]));
      stubArchive(
        _page([
          _anime(4017, 'cyberpunk-edgerunners', 120377),
          _anime(7803, 'cyberpunk-edgerunners-2', 195539),
        ]),
        title: 'Cyberpunk: Edgerunners',
      );

      final found = await service.findEntries(
        AnimeMatch(kitsuId: '50016', absoluteEpisode: 1, anilistId: 195539),
      );

      expect(found!.entries.map((e) => e.id), [7803]);
      expect(searched(), [
        {'query': 'Cyberpunk: Edgerunners II', 'page': 1},
        {'query': 'CYBERPUNK: EDGERUNNERS II', 'page': 1},
        {'query': 'Cyberpunk: Edgerunners', 'page': 1},
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

    test('a site error on the search is thrown too', () async {
      stubKitsu();
      when(
        () => dio.get(
          '$_siteAddress/api/archive',
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          response: Response(requestOptions: RequestOptions(), statusCode: 429),
          type: DioExceptionType.badResponse,
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
