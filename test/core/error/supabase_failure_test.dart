import 'dart:async';
import 'dart:io';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/error/supabase_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('supabaseErrorToFailure', () {
    test('a PostgREST error becomes a ServerFailure that keeps the cause', () {
      const error = PostgrestException(message: 'boom', code: '23505');

      final failure = supabaseErrorToFailure(error);

      expect(failure, isA<ServerFailure>());
      expect(failure.cause, same(error));
      expect((failure as ServerFailure).statusCode, isNull);
    });

    test('a numeric PostgREST code is kept as the status code', () {
      final failure = supabaseErrorToFailure(
        const PostgrestException(message: 'bad gateway', code: '502'),
      );

      expect((failure as ServerFailure).statusCode, 502);
    });

    test('not signed in / not allowed / expired token become AuthFailure', () {
      for (final code in ['28000', '42501', 'PGRST301']) {
        expect(
          supabaseErrorToFailure(PostgrestException(message: 'no', code: code)),
          isA<AuthFailure>(),
          reason: code,
        );
      }
      expect(
        supabaseErrorToFailure(const AuthException('expired')),
        isA<AuthFailure>(),
      );
    });

    test('offline and timeouts become NetworkFailure', () {
      expect(
        supabaseErrorToFailure(const SocketException('offline')),
        isA<NetworkFailure>(),
      );
      expect(
        supabaseErrorToFailure(TimeoutException('slow')),
        isA<NetworkFailure>(),
      );
    });

    test('anything else becomes UnknownFailure; a failure stays as it is', () {
      expect(supabaseErrorToFailure(StateError('x')), isA<UnknownFailure>());

      const failure = NotFoundFailure('gone');
      expect(supabaseErrorToFailure(failure), same(failure));
    });
  });

  test('withAppFailure rethrows a Supabase error as an AppFailure', () {
    final call = Future<void>.error(
      const PostgrestException(message: 'boom'),
    ).withAppFailure();

    expect(call, throwsA(isA<ServerFailure>()));
  });
}
