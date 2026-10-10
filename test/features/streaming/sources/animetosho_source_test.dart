import 'package:cinemuse_app/features/streaming/anime/models/kitsu_mapping.dart';
import 'package:cinemuse_app/features/streaming/models/stream_search_context.dart';
import 'package:cinemuse_app/features/streaming/sources/animetosho_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;

  setUp(() {
    dio = _MockDio();
    when(
      () => dio.get<dynamic>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (inv) async => Response<dynamic>(
        requestOptions: RequestOptions(path: inv.positionalArguments.first),
        statusCode: 200,
        data: <dynamic>[],
      ),
    );
  });

  test('asks the current AnimeTosho feed host (REV-231)', () async {
    final source = AnimeToshoSource(dio);
    final context = StreamSearchContext(
      tmdbId: '88046',
      type: 'tv',
      title: 'Test Anime',
      isAnime: true,
      mapping: KitsuMapping(kitsuId: '1', anidbId: 123, absoluteEpisode: 5),
    );

    await source.search(context);

    final urls = verify(
      () => dio.get<dynamic>(
        captureAny(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).captured.cast<String>();
    expect(urls, isNotEmpty);
    // feed.animetosho.org no longer exists (no DNS record).
    expect(urls, everyElement('https://feed.animetosho.net/json'));
  });
}
