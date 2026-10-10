import 'package:cinemuse_app/core/application/l10n_provider.dart';
import 'package:cinemuse_app/core/error/app_exception.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/streaming/models/streaming_exceptions.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

class UserFriendlyError {
  final String message;
  final String? title;
  final String? hint;
  final AppExceptionType type;

  UserFriendlyError({
    required this.message,
    this.title,
    this.hint,
    this.type = AppExceptionType.unknown,
  });
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
            type: AppExceptionType.network,
          );
        case DioExceptionType.badResponse:
          return UserFriendlyError(
            message: l10n.errorServerStatus(
              '${error.response?.statusCode ?? '?'}',
            ),
            type: AppExceptionType.network,
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
            type: AppExceptionType.network,
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
        type: AppExceptionType.network,
      ),
      AuthFailure() => UserFriendlyError(
        message: l10n.failureAuth,
        type: AppExceptionType.auth,
      ),
      ServerFailure() => UserFriendlyError(
        message: l10n.failureServer,
        type: AppExceptionType.database,
      ),
      NotFoundFailure() => UserFriendlyError(message: l10n.failureNotFound),
      StreamingFailure() => UserFriendlyError(
        message: l10n.failureStreaming,
        type: AppExceptionType.streaming,
      ),
      ValidationFailure() => UserFriendlyError(
        message: l10n.failureValidation,
        type: AppExceptionType.validation,
      ),
      UnknownFailure() => UserFriendlyError(message: l10n.failureUnknown),
    };
  }
}

/// Sign-in / sign-up errors, as [SupabaseErrorHandler] wraps them, mapped to
/// translated text by Supabase's (English) message.
class AuthErrorMapper implements BaseErrorMapper {
  @override
  UserFriendlyError? map(Object error, AppLocalizations l10n) {
    final authError = switch (error) {
      AuthException() => error,
      AppException(originalError: final AuthException original) => original,
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
    return UserFriendlyError(message: message, type: AppExceptionType.auth);
  }
}

class StreamingErrorMapper implements BaseErrorMapper {
  @override
  UserFriendlyError? map(Object error, AppLocalizations l10n) {
    if (error is! StreamingException) return null;
    final message = switch (error) {
      NoProvidersEnabledException() => l10n.streamingErrorNoProviders,
      CapabilityMissingException(:final category) =>
        l10n.streamingErrorCapabilityMissing(category),
      NoResultsFoundException() => l10n.streamingErrorNoResults,
      MediaDetailsResolutionException() => l10n.streamingErrorMediaDetails,
      ImdbIdResolutionException() => l10n.streamingErrorImdbId,
      ProviderSearchException(:final providerName) =>
        l10n.streamingErrorProviderSearchFailed(providerName),
      _ => error.message,
    };
    return UserFriendlyError(
      message: message,
      type: AppExceptionType.streaming,
    );
  }
}

class GlobalErrorMapper {
  final AppLocalizations _l10n;
  final List<BaseErrorMapper> _mappers = [
    AppFailureMapper(),
    AuthErrorMapper(),
    NetworkErrorMapper(),
    StreamingErrorMapper(),
  ];

  GlobalErrorMapper(this._l10n);

  UserFriendlyError map(Object error) {
    for (final mapper in _mappers) {
      final result = mapper.map(error, _l10n);
      if (result != null) return result;
    }
    // Never show `message` / `toString()`: raw English developer text (REV-164).
    return switch (error) {
      AppException() => UserFriendlyError(
        message: _messageForType(error.type),
        type: error.type,
      ),
      String() => UserFriendlyError(message: error),
      _ => UserFriendlyError(message: _l10n.failureUnknown),
    };
  }

  String _messageForType(AppExceptionType type) => switch (type) {
    AppExceptionType.network => _l10n.failureNetwork,
    AppExceptionType.auth => _l10n.failureAuth,
    AppExceptionType.database => _l10n.failureServer,
    AppExceptionType.streaming => _l10n.failureStreaming,
    AppExceptionType.validation => _l10n.failureValidation,
    AppExceptionType.realtime ||
    AppExceptionType.system ||
    AppExceptionType.unknown => _l10n.failureUnknown,
  };
}

final errorMapperProvider = Provider<GlobalErrorMapper>((ref) {
  final l10n = ref.watch(localizationsProvider);
  return GlobalErrorMapper(l10n);
});
