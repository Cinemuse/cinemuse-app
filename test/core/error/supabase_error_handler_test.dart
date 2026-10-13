import 'dart:async';
import 'dart:io';

import 'package:cinemuse_app/core/error/app_exception.dart';
import 'package:cinemuse_app/core/error/supabase_error_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // REV-260: offline errors were "unknown", so the UI said "something went
  // wrong" instead of "no connection".
  group('offline errors are network errors', () {
    test('no host lookup', () {
      final error = SupabaseErrorHandler.handleError(
        const SocketException('Failed host lookup'),
      );
      expect(error.type, AppExceptionType.network);
    });

    test('timeout', () {
      final error = SupabaseErrorHandler.handleError(TimeoutException('slow'));
      expect(error.type, AppExceptionType.network);
    });
  });

  test('anything else stays unknown', () {
    final error = SupabaseErrorHandler.handleError(StateError('bug'));
    expect(error.type, AppExceptionType.unknown);
  });
}
