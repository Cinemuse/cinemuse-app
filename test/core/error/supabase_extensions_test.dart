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
}
