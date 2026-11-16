/// The error type that services and repositories throw.
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

/// Why the stream search found nothing to play.
enum NoStreamsReason {
  /// No streaming add-on is turned on.
  noAddons,

  /// The title's details (needed to search) couldn't be fetched.
  noDetails,

  /// The add-ons found no stream.
  noResults,

  /// The search, or the picked link, failed.
  linkFailed,
}

/// The stream search ended without a stream to play ([reason]).
final class NoStreamsFailure extends AppFailure {
  final NoStreamsReason reason;

  const NoStreamsFailure(
    this.reason,
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

/// Why a debrid service didn't give the file.
enum DebridRefusal {
  /// Not ready yet: it is downloading the torrent now.
  downloading,

  /// The service refuses the file for copyright.
  copyright,

  /// Too many downloads running, or another account limit.
  limit,

  /// Any other reason.
  other,
}

/// An add-on sent its own short error video instead of the file, because
/// the debrid service behind it didn't give the file ([reason]).
final class DebridFileFailure extends AppFailure {
  final DebridRefusal reason;

  const DebridFileFailure(
    this.reason,
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

/// Bad input, or data in an unexpected shape.
final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, {super.cause, super.stackTrace});
}

/// Anything that fits no other failure.
final class UnknownFailure extends AppFailure {
  const UnknownFailure(super.message, {super.cause, super.stackTrace});
}
