import 'package:cinemuse_app/core/application/l10n_provider.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

/// What went wrong, as the error widgets show it (one icon per kind).
enum ErrorKind { network, auth, server, streaming, validation, unknown }

/// An error ready for the UI: translated text plus its [kind].
class UserFriendlyError {
  final String message;
  final String? title;
  final String? hint;
  final ErrorKind kind;

  UserFriendlyError({
    required this.message,
    this.title,
    this.hint,
    this.kind = ErrorKind.unknown,
  });
}

/// The error as first thrown. Riverpod wraps an error in a
/// [ProviderException] each time a provider fails because one it awaited
/// failed.
Object unwrapProviderError(Object error) {
  var unwrapped = error;
  while (unwrapped is ProviderException) {
    unwrapped = unwrapped.exception;
  }
  return unwrapped;
}

abstract class BaseErrorMapper {
  UserFriendlyError? map(Object error, AppLocalizations l10n);
}

class NetworkErrorMapper implements BaseErrorMapper {
  @override
  UserFriendlyError? map(Object error, AppLocalizations l10n) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return UserFriendlyError(
            message: l10n.errorTimeout,
            kind: ErrorKind.network,
          );
        case DioExceptionType.badResponse:
          return UserFriendlyError(
            message: l10n.errorServerStatus(
              '${error.response?.statusCode ?? '?'}',
            ),
            kind: ErrorKind.network,
          );
        default:
          final underlying = error.error?.toString() ?? '';
          final isCertificateProblem =
              underlying.contains('HandshakeException') ||
              underlying.contains('CertificateException') ||
              underlying.contains('TlsException');

          return UserFriendlyError(
            message: l10n.failureNetwork,
            hint: isCertificateProblem ? l10n.errorCertificateHint : null,
            kind: ErrorKind.network,
          );
      }
    }
    return null;
  }
}

/// Maps an [AppFailure] to translated text. Never shows [AppFailure.message]:
/// that is English developer text (REV-164).
class AppFailureMapper implements BaseErrorMapper {
  @override
  UserFriendlyError? map(Object error, AppLocalizations l10n) {
    if (error is! AppFailure) return null;
    return switch (error) {
      NetworkFailure() => UserFriendlyError(
        message: l10n.failureNetwork,
        kind: ErrorKind.network,
      ),
      AuthFailure() => UserFriendlyError(
        message: l10n.failureAuth,
        kind: ErrorKind.auth,
      ),
      ServerFailure() => UserFriendlyError(
        message: l10n.failureServer,
        kind: ErrorKind.server,
      ),
      NotFoundFailure() => UserFriendlyError(message: l10n.failureNotFound),
      StreamingFailure() => UserFriendlyError(
        message: l10n.failureStreaming,
        kind: ErrorKind.streaming,
      ),
      NoStreamsFailure(:final reason) => UserFriendlyError(
        message: switch (reason) {
          NoStreamsReason.noAddons => l10n.streamingErrorNoProviders,
          NoStreamsReason.noDetails => l10n.streamingErrorMediaDetails,
          NoStreamsReason.noResults => l10n.streamingErrorNoResults,
          NoStreamsReason.linkFailed => l10n.streamingErrorResolutionFailed,
        },
        kind: ErrorKind.streaming,
      ),
      DebridFileFailure(:final reason) => UserFriendlyError(
        message: switch (reason) {
          DebridRefusal.downloading => l10n.debridFileDownloading,
          DebridRefusal.copyright => l10n.debridFileCopyright,
          DebridRefusal.limit => l10n.debridFileLimit,
          DebridRefusal.other => l10n.debridFileOther,
        },
        kind: ErrorKind.streaming,
      ),
      ValidationFailure() => UserFriendlyError(
        message: l10n.failureValidation,
        kind: ErrorKind.validation,
      ),
      UnknownFailure() => UserFriendlyError(message: l10n.failureUnknown),
    };
  }
}

/// Sign-in errors (an [AuthException], also inside an [AuthFailure]), mapped
/// to translated text by Supabase's (English) message. Runs before
/// [AppFailureMapper], whose "sign in again" text would hide the reason.
class AuthErrorMapper implements BaseErrorMapper {
  @override
  UserFriendlyError? map(Object error, AppLocalizations l10n) {
    final authError = switch (error) {
      AuthException() => error,
      AuthFailure(cause: final AuthException original) => original,
      _ => null,
    };
    if (authError == null) return null;

    final text = authError.message.toLowerCase();
    final message = text.contains('invalid login credentials')
        ? l10n.authErrorInvalidCredentials
        : text.contains('email not confirmed')
        ? l10n.authErrorEmailNotConfirmed
        : text.contains('already exists') || text.contains('already registered')
        ? l10n.authErrorUserExists
        : l10n.authErrorGeneric;
    return UserFriendlyError(message: message, kind: ErrorKind.auth);
  }
}

class GlobalErrorMapper {
  final AppLocalizations _l10n;
  final List<BaseErrorMapper> _mappers = [
    AuthErrorMapper(),
    AppFailureMapper(),
    NetworkErrorMapper(),
  ];

  GlobalErrorMapper(this._l10n);

  UserFriendlyError map(Object wrapped) {
    final error = unwrapProviderError(wrapped);
    for (final mapper in _mappers) {
      final result = mapper.map(error, _l10n);
      if (result != null) return result;
    }
    // Never show `message` / `toString()`: raw English developer text (REV-164).
    return switch (error) {
      String() => UserFriendlyError(message: error),
      _ => UserFriendlyError(message: _l10n.failureUnknown),
    };
  }
}

final errorMapperProvider = Provider<GlobalErrorMapper>((ref) {
  final l10n = ref.watch(localizationsProvider);
  return GlobalErrorMapper(l10n);
});
