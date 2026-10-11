import 'dart:typed_data';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with [statusCode] and [body], or fails like an
/// offline device when [offline] is set. Remembers the last request.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({this.statusCode = 200, this.body = '{}', this.offline = false});

  final int statusCode;
  final String body;
  final bool offline;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Failed host lookup',
      );
    }
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

TmdbService _service(_FakeAdapter adapter) =>
    TmdbService(Dio()..httpClientAdapter = adapter, 'en-US');

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'TMDB_API_KEY=secret-key');
  });

  setUp(AppLogger.clearRecent);

  group('lists throw instead of looking empty (REV-30)', () {
    test('search while offline throws a NetworkFailure', () async {
      final service = _service(_FakeAdapter(offline: true));

      await expectLater(
        service.searchMulti('inception'),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('discover with TMDB down throws a ServerFailure', () async {
      final service = _service(_FakeAdapter(statusCode: 503));

      await expectLater(
        service.discover(type: 'movie', page: 2),
        throwsA(
          isA<ServerFailure>().having((f) => f.statusCode, 'status', 503),
        ),
      );
    });

    test('popular persons while offline throws', () async {
      final service = _service(_FakeAdapter(offline: true));

      await expectLater(
        service.getPopularPersons(1),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('watch providers while offline throws', () async {
      final service = _service(_FakeAdapter(offline: true));

      await expectLater(
        service.getWatchProviders('movie', 'IT'),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('the failure message never contains the API key', () async {
      final service = _service(_FakeAdapter(statusCode: 500));

      final failure = await service
          .searchMulti('inception')
          .then<AppFailure?>(
            (_) => null,
            onError: (Object e) => e as AppFailure,
          );

      expect(failure!.message, isNot(contains('secret-key')));
    });
  });

  test('search still sends the key and the query', () async {
    final adapter = _FakeAdapter(
      body: '{"results": [{"id": 1}], "total_pages": 3}',
    );

    final page = await _service(adapter).searchMulti('inception');

    expect(page.totalPages, 3);
    expect(page.results, [
      {'id': 1},
    ]);
    expect(adapter.lastRequest!.queryParameters['api_key'], 'secret-key');
    expect(adapter.lastRequest!.queryParameters['query'], 'inception');
  });

  group('single lookups still return null, but log why', () {
    test(
      'details while offline: null and a log line without the key',
      () async {
        final service = _service(_FakeAdapter(offline: true));

        expect(await service.getMediaDetails('27205', 'movie'), isNull);

        final logged = AppLogger.recent.map((e) => e.message).join('\n');
        expect(logged, contains('/movie/27205'));
        expect(logged, isNot(contains('secret-key')));
      },
    );

    test('a 404 is a real "not found": null and no warning', () async {
      final service = _service(_FakeAdapter(statusCode: 404));

      expect(await service.getPersonDetails(42), isNull);
      expect(AppLogger.recent, isEmpty);
    });
  });
}
