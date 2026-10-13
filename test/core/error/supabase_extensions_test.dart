import 'dart:async';

import 'package:cinemuse_app/core/error/app_exception.dart';
import 'package:cinemuse_app/core/error/supabase_extensions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('withErrorHandling keeps the original stack trace (REV-16)', () async {
    final original = StackTrace.current;
    final call = Future<void>.error(
      const PostgrestException(message: 'boom'),
      original,
    );

    StackTrace? caught;
    try {
      await call.withErrorHandling();
    } on AppException catch (_, st) {
      caught = st;
    }

    expect(caught.toString(), original.toString());
  });

  // REV-197: `handleError` ignored the returned value, so a realtime error
  // before the first event left the screen loading forever.
  group('realtimeErrorsAs', () {
    final realtime = AppException(
      message: 'channel closed',
      type: AppExceptionType.realtime,
    );

    test('a realtime error before any data becomes the empty value', () {
      final stream = Stream<List<int>>.error(realtime).realtimeErrorsAs([]);
      expect(stream, emitsInOrder([<int>[], emitsDone]));
    });

    test('a realtime error after data keeps the last value', () {
      final controller = StreamController<List<int>>();
      final stream = controller.stream.realtimeErrorsAs([]);
      controller
        ..add([1])
        ..addError(realtime)
        ..close();
      expect(
        stream,
        emitsInOrder([
          [1],
          emitsDone,
        ]),
      );
    });

    test('other errors still arrive as errors', () {
      final stream = Stream<List<int>>.error(
        AppException(message: 'offline', type: AppExceptionType.network),
      ).realtimeErrorsAs([]);
      expect(stream, emitsError(isA<AppException>()));
    });
  });
}
