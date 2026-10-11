import 'package:cinemuse_app/core/utils/url_utils.dart';
import 'package:cinemuse_app/features/streaming/anime/models/kitsu_mapping.dart';
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
      mapping: KitsuMapping(kitsuId: '7442', absoluteEpisode: 5),
    );

    setUp(() => dio = _MockDio());

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
