import 'package:cinemuse_app/core/data/server_addresses_model.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/streaming/anime/models/anime_match.dart';
import 'package:cinemuse_app/features/streaming/models/stream_search_context.dart';
import 'package:cinemuse_app/features/streaming/sources/anime_torrent_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

/// Not the feed's real address: the source must use the server list's.
const _feedAddress = 'https://torrents.example/json';

ServerAddressesLoader _addressesWith(String? feed) =>
    () async => ServerAddresses.fromRows([
      if (feed != null)
        {'key': ServerAddress.animeTorrents.key, 'address': feed},
    ]);

final _context = StreamSearchContext(
  tmdbId: '88046',
  type: 'tv',
  title: 'Test Anime',
  isAnime: true,
  mapping: AnimeMatch(
    anilistId: 7,
    kitsuId: '1',
    anidbId: 123,
    absoluteEpisode: 5,
  ),
);

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

  test("asks the feed at the server list's address", () async {
    final source = AnimeTorrentSource(
      dio,
      _addressesWith(_feedAddress),
      name: 'Torrent Feed',
    );

    await source.search(_context);

    final urls = verify(
      () => dio.get<dynamic>(
        captureAny(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).captured.cast<String>();
    expect(urls, isNotEmpty);
    expect(urls, everyElement(_feedAddress));
  });

  test('no address in the list: finds nothing, asks nothing', () async {
    final source = AnimeTorrentSource(
      dio,
      _addressesWith(null),
      name: 'Torrent Feed',
    );

    expect(await source.search(_context), isEmpty);
    verifyZeroInteractions(dio);
  });

  test('no address list at all: finds nothing, asks nothing', () async {
    final source = AnimeTorrentSource(
      dio,
      () async => throw const NetworkFailure('offline'),
      name: 'Torrent Feed',
    );

    expect(await source.search(_context), isEmpty);
    verifyZeroInteractions(dio);
  });
}
