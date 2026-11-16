import 'dart:typed_data';

import 'package:cinemuse_app/core/network/retry_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with [statusCode] and counts the calls.
class _CountingAdapter implements HttpClientAdapter {
  _CountingAdapter(this.statusCode);

  final int statusCode;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString('', statusCode);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio dio;
  late _CountingAdapter adapter;

  setUp(() {
    adapter = _CountingAdapter(503);
    dio = Dio()..httpClientAdapter = adapter;
    dio.interceptors.add(RetryInterceptor(dio, baseDelay: Duration.zero));
  });

  test('a GET is retried on 503, then fails', () async {
    await expectLater(
      dio.get<void>('https://example.com'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.calls, 1 + RetryInterceptor.defaultMaxRetries);
  });

  test('a GET marked skip-retry is tried once (REV-259)', () async {
    await expectLater(
      dio.get<void>(
        'https://example.com',
        options: Options(extra: {RetryInterceptor.skipRetryKey: true}),
      ),
      throwsA(isA<DioException>()),
    );
    expect(adapter.calls, 1);
  });

  test('a POST is never re-sent (STR-11)', () async {
    await expectLater(
      dio.post<void>('https://example.com', data: {'magnet': 'x'}),
      throwsA(isA<DioException>()),
    );
    expect(adapter.calls, 1);
  });

  test('a 404 is not retried', () async {
    adapter = _CountingAdapter(404);
    dio.httpClientAdapter = adapter;

    await expectLater(
      dio.get<void>('https://example.com'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.calls, 1);
  });
}
