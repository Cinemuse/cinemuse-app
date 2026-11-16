import 'dart:async';
import 'dart:io';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Postgres / PostgREST error codes that mean "not signed in or not allowed".
const _authErrorCodes = {
  '28000', // invalid_authorization_specification (our RPCs: no auth.uid())
  '42501', // insufficient_privilege (e.g. anon calling a signed-in-only RPC)
  'PGRST301', // JWT expired or invalid
};

/// Turns an error thrown by the Supabase client into the matching
/// [AppFailure], keeping the original as `cause`. An [AppFailure] is returned
/// unchanged.
AppFailure supabaseErrorToFailure(Object error, [StackTrace? stackTrace]) {
  if (error is AppFailure) return error;
  return switch (error) {
    AuthException() => AuthFailure(
      error.message,
      cause: error,
      stackTrace: stackTrace,
    ),
    PostgrestException(:final code) when _authErrorCodes.contains(code) =>
      AuthFailure(error.message, cause: error, stackTrace: stackTrace),
    PostgrestException(:final code) => ServerFailure(
      error.message,
      statusCode: _httpStatus(code),
      cause: error,
      stackTrace: stackTrace,
    ),
    // A dropped live (realtime) connection.
    RealtimeSubscribeException() ||
    SocketException() ||
    TlsException() ||
    TimeoutException() => NetworkFailure(
      error.toString(),
      cause: error,
      stackTrace: stackTrace,
    ),
    // package:http's ClientException (offline, connection reset). Matched by
    // name because `http` is only a transitive dependency.
    _ when error.runtimeType.toString() == 'ClientException' => NetworkFailure(
      error.toString(),
      cause: error,
      stackTrace: stackTrace,
    ),
    _ => UnknownFailure(error.toString(), cause: error, stackTrace: stackTrace),
  };
}

/// PostgREST puts the HTTP status in `code` only when the error body wasn't
/// JSON. Postgres codes can be all digits too (`23505`), but have 5.
int? _httpStatus(String? code) =>
    code != null && code.length == 3 ? int.tryParse(code) : null;

extension SupabaseFailureFuture<T> on Future<T> {
  /// Awaits a Supabase call and rethrows any error as an [AppFailure]
  /// (see [supabaseErrorToFailure]).
  Future<T> withAppFailure() async {
    try {
      return await this;
    } catch (e, st) {
      // Keep the caller's stack trace, or every log points at this helper.
      Error.throwWithStackTrace(supabaseErrorToFailure(e, st), st);
    }
  }
}

extension SupabaseFailureStream<T> on Stream<T> {
  /// Passes every error on as an [AppFailure] (see [supabaseErrorToFailure]).
  Stream<T> withAppFailure() {
    return transform(
      StreamTransformer.fromHandlers(
        handleError: (error, stackTrace, sink) {
          sink.addError(supabaseErrorToFailure(error, stackTrace), stackTrace);
        },
      ),
    );
  }

  /// A dropped live connection before the first event becomes [empty], so
  /// a screen waiting for it doesn't spin forever; after it, the error is
  /// dropped and the last value stays (REV-197). Other errors pass through.
  Stream<T> realtimeErrorsAs(T empty) {
    var hasData = false;
    return transform(
      StreamTransformer.fromHandlers(
        handleData: (data, sink) {
          hasData = true;
          sink.add(data);
        },
        handleError: (error, stackTrace, sink) {
          if (!_isDroppedLiveConnection(error)) {
            sink.addError(error, stackTrace);
          } else if (!hasData) {
            hasData = true;
            sink.add(empty);
          }
        },
      ),
    );
  }
}

bool _isDroppedLiveConnection(Object error) =>
    error is NetworkFailure && error.cause is RealtimeSubscribeException;
