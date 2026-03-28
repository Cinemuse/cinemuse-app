import 'package:cinemuse_app/core/application/l10n_provider.dart';
import 'package:cinemuse_app/core/error/app_exception.dart';
import 'package:cinemuse_app/core/services/streaming/models/streaming_exceptions.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
            message: "Connection timed out",
            hint: "Check your internet connection",
            type: AppExceptionType.network,
          );
        case DioExceptionType.badResponse:
          return UserFriendlyError(
            message: "Server returned an error (${error.response?.statusCode})",
            type: AppExceptionType.network,
          );
        default:
          final underlying = error.error?.toString() ?? '';
          final detail = error.message != null ? ': ${error.message}' : '';
          
          String? hint;
          if (underlying.contains('HandshakeException') || underlying.contains('CertificateException') || underlying.contains('TlsException')) {
             hint = "Your system might be missing some root certificates. Try updating Windows or check your firewall/DNS.";
          }

          return UserFriendlyError(
            message: "Network error occurred$detail",
            hint: hint,
            type: AppExceptionType.network,
          );
      }
    }
    return null;
  }
}

class StreamingErrorMapper implements BaseErrorMapper {
  @override
  UserFriendlyError? map(Object error, AppLocalizations l10n) {
    if (error is StreamingException) {
      if (error is NoProvidersEnabledException) {
        return UserFriendlyError(message: l10n.streamingErrorNoProviders, type: AppExceptionType.streaming);
      }
      if (error is CapabilityMissingException) {
        return UserFriendlyError(
          message: l10n.streamingErrorCapabilityMissing(error.category),
          type: AppExceptionType.streaming,
        );
      }
      if (error is NoResultsFoundException) {
        return UserFriendlyError(message: l10n.streamingErrorNoResults, type: AppExceptionType.streaming);
      }
      if (error is MediaDetailsResolutionException) {
        return UserFriendlyError(message: l10n.streamingErrorMediaDetails, type: AppExceptionType.streaming);
      }
      if (error is ImdbIdResolutionException) {
        return UserFriendlyError(message: l10n.streamingErrorImdbId, type: AppExceptionType.streaming);
      }
      if (error is ProviderSearchException) {
        return UserFriendlyError(
          message: l10n.streamingErrorProviderSearchFailed(error.providerName),
          type: AppExceptionType.streaming,
        );
      }
      return UserFriendlyError(message: error.message, type: AppExceptionType.streaming);
    }
    return null;
  }
}

class GlobalErrorMapper {
  final AppLocalizations _l10n;
  final List<BaseErrorMapper> _mappers = [
    NetworkErrorMapper(),
    StreamingErrorMapper(),
    // Add SupabaseErrorMapper here when implemented
  ];

  GlobalErrorMapper(this._l10n);

  UserFriendlyError map(Object error) {
    // 1. Try specialized mappers
    for (final mapper in _mappers) {
      final result = mapper.map(error, _l10n);
      if (result != null) return result;
    }

    // 2. Handle base AppException
    if (error is AppException) {
      return UserFriendlyError(message: error.message, type: error.type);
    }

    // 3. Fallback for strings
    if (error is String) {
      return UserFriendlyError(message: error);
    }

    // 4. Default fallback
    return UserFriendlyError(message: error.toString());
  }
}

final errorMapperProvider = Provider<GlobalErrorMapper>((ref) {
  final l10n = ref.watch(localizationsProvider);
  return GlobalErrorMapper(l10n);
});
