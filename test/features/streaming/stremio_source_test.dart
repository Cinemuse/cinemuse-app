import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/core/utils/url_utils.dart';
import 'package:cinemuse_app/features/streaming/anime/models/anime_match.dart';
import 'package:cinemuse_app/features/streaming/models/stream_search_context.dart';
import 'package:cinemuse_app/features/streaming/sources/stremio_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() => registerFallbackValue(Options()));

  group('StremioSource results (REV-31)', () {
    late _MockDio dio;

    void answerWith(List<Map<String, dynamic>> streams) {
      when(
        () => dio.get<dynamic>(any(), options: any(named: 'options')),
      ).thenAnswer(
        (inv) async => Response<dynamic>(
          requestOptions: RequestOptions(path: inv.positionalArguments.first),
          statusCode: 200,
          data: {'streams': streams},
        ),
      );
    }

    final animeContext = StreamSearchContext(
      tmdbId: '1429',
      type: 'tv',
      title: 'Attack on Titan',
      isAnime: true,
      mapping: AnimeMatch(
        anilistId: 16498,
        kitsuId: '7442',
        absoluteEpisode: 5,
      ),
    );

    setUp(() => dio = _MockDio());

    String askedPath() =>
        verify(
              () => dio.get<dynamic>(
                captureAny(),
                options: any(named: 'options'),
              ),
            ).captured.single
            as String;

    test('an anime is asked by its Kitsu id and anime episode', () async {
      answerWith([]);

      await StremioSource(dio, 'https://x').search(animeContext);

      expect(askedPath(), 'https://x/stream/anime/kitsu:7442:5.json');
    });

    test('an anime Kitsu does not know is asked by IMDb id', () async {
      answerWith([]);

      await StremioSource(dio, 'https://x').search(
        StreamSearchContext(
          tmdbId: '1429',
          imdbId: 'tt2560140',
          type: 'tv',
          season: 1,
          episode: 5,
          title: 'Attack on Titan',
          isAnime: true,
          mapping: const AnimeMatch(anilistId: 16498, absoluteEpisode: 5),
        ),
      );

      expect(askedPath(), 'https://x/stream/series/tt2560140:1:5.json');
    });

    test('reads seeders from the title when seeds is missing', () async {
      answerWith([
        {
          'name': 'Torrentio\n1080p',
          'title': 'Show.S01E05.1080p.WEB\n👤 123 💾 1.2 GB ⚙️ ThePirateBay',
          'infoHash': 'abc',
        },
      ]);

      final results = await StremioSource(
        dio,
        'https://x',
      ).search(animeContext);

      expect(results.single.seeds, 123);
    });

    test('prefers the seeds field when the addon sends it', () async {
      answerWith([
        {'title': 'Show 👤 5', 'seeds': 42, 'infoHash': 'abc'},
      ]);

      final results = await StremioSource(
        dio,
        'https://x',
      ).search(animeContext);

      expect(results.single.seeds, 42);
    });

    // STR-04: the debrid file picker needs the add-on's file hints.
    test('keeps the file index and file name the addon sends', () async {
      answerWith([
        {
          'title': 'Show S01 pack',
          'infoHash': 'abc',
          'fileIdx': 4,
          'behaviorHints': {'filename': 'Show.S01E05.mkv'},
        },
      ]);

      final result = (await StremioSource(
        dio,
        'https://x',
      ).search(animeContext)).single;

      expect(result.fileIndex, 4);
      expect(result.fileName, 'Show.S01E05.mkv');
    });

    test('anime titles carry no debug prefix', () async {
      answerWith([
        {'title': 'Show.S01E05', 'infoHash': 'abc'},
      ]);

      final results = await StremioSource(
        dio,
        'https://x',
      ).search(animeContext);

      expect(results.single.title, 'Show.S01E05');
    });

    test('never logs the add-on URL, which holds the key (SEC-06)', () async {
      AppLogger.clearRecent();
      answerWith([
        {'title': 'Show.S01E05', 'infoHash': 'abc'},
      ]);

      await StremioSource(
        dio,
        'https://torrentio.test/realdebrid=SECRETKEY',
        queryParams: 'apikey=SECRETKEY',
      ).search(animeContext);

      expect(AppLogger.recent, isNotEmpty);
      expect(
        AppLogger.recent.map((e) => e.message),
        everyElement(isNot(contains('SECRETKEY'))),
      );
    });

    test('a title without seeders gives 0', () {
      expect(StremioSource.seedersFromTitle('Show.S01E05 💾 1 GB'), 0);
    });
  });

  group('StremioSource URL Cleaning', () {
    test(
      'UrlUtils.splitStremioUrl base URL should strip /manifest.json and everything after it',
      () {
        final testCases = {
          "https://addon.com/manifest.json": "https://addon.com",
          "https://addon.com/manifest.json/": "https://addon.com",
          "https://addon.com/manifest.json/stream/movie/tt123.json":
              "https://addon.com",
          "https://addon.com/": "https://addon.com",
          "https://addon.com": "https://addon.com",
          "https://mediafusion.elfhosted.com/D-hzHx.../manifest.json/stream/series/tt...":
              "https://mediafusion.elfhosted.com/D-hzHx...",
        };

        testCases.forEach((input, expected) {
          expect(UrlUtils.splitStremioUrl(input).baseUrl, equals(expected));
        });
      },
    );
  });
}
