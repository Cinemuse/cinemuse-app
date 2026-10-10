/// The error type that services and repositories throw (see CONVENTIONS.md →
/// Errors).
///
/// Sealed, so a `switch` over a failure must handle every subclass.
/// [message] is English text for developers and logs; the UI shows translated
/// text through the error mapper instead.
sealed class AppFailure implements Exception {
  final String message;

  /// The original library error (`DioException`, `PostgrestException`, …).
  final Object? cause;
  final StackTrace? stackTrace;

  const AppFailure(this.message, {this.cause, this.stackTrace});

  @override
  String toString() {
    final causeText = cause == null ? '' : ' (cause: $cause)';
    return '$runtimeType: $message$causeText';
  }
}

/// Offline, timeout, DNS or certificate problems.
final class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, {super.cause, super.stackTrace});
}

/// Not signed in, session expired or wrong credentials.
final class AuthFailure extends AppFailure {
  const AuthFailure(super.message, {super.cause, super.stackTrace});
}

/// A backend (Supabase, edge function, TMDB) answered with an error.
final class ServerFailure extends AppFailure {
  /// HTTP status code, when there is one.
  final int? statusCode;

  const ServerFailure(
    super.message, {
    this.statusCode,
    super.cause,
    super.stackTrace,
  });
}

/// Something that must exist is missing. When "not found" is a normal
/// answer, return `null` instead.
final class NotFoundFailure extends AppFailure {
  const NotFoundFailure(super.message, {super.cause, super.stackTrace});
}

/// Finding or playing a stream failed.
final class StreamingFailure extends AppFailure {
  const StreamingFailure(super.message, {super.cause, super.stackTrace});
}

/// Bad input, or data in an unexpected shape.
final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, {super.cause, super.stackTrace});
}

/// Anything that fits no other failure.
final class UnknownFailure extends AppFailure {
  const UnknownFailure(super.message, {super.cause, super.stackTrace});
}
