import 'package:cinemuse_app/core/error/app_exception.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/core/services/streaming/models/streaming_exceptions.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final mapper = GlobalErrorMapper(l10n);

  group('GlobalErrorMapper with AppFailure', () {
    final cases = <AppFailure, (String, AppExceptionType)>{
      const NetworkFailure('dev text'): (
        l10n.failureNetwork,
        AppExceptionType.network,
      ),
      const AuthFailure('dev text'): (l10n.failureAuth, AppExceptionType.auth),
      const ServerFailure('dev text', statusCode: 500): (
        l10n.failureServer,
        AppExceptionType.database,
      ),
      const NotFoundFailure('dev text'): (
        l10n.failureNotFound,
        AppExceptionType.unknown,
      ),
      const StreamingFailure('dev text'): (
        l10n.failureStreaming,
        AppExceptionType.streaming,
      ),
      const ValidationFailure('dev text'): (
        l10n.failureValidation,
        AppExceptionType.validation,
      ),
      const UnknownFailure('dev text'): (
        l10n.failureUnknown,
        AppExceptionType.unknown,
      ),
    };

    cases.forEach((failure, expected) {
      test('${failure.runtimeType} → translated text and icon type', () {
        final result = mapper.map(failure);

        expect(result.message, expected.$1);
        expect(result.type, expected.$2);
        // The developer message must never reach the user (REV-164).
        expect(result.message, isNot(contains('dev text')));
      });
    });

    test('uses the Italian text for the Italian locale', () {
      final it = lookupAppLocalizations(const Locale('it'));
      final result = GlobalErrorMapper(
        it,
      ).map(const NetworkFailure('dev text'));

      expect(result.message, it.failureNetwork);
      expect(result.message, isNot(l10n.failureNetwork));
    });
  });

  group('GlobalErrorMapper with AppException', () {
    final cases = <AppExceptionType, String>{
      AppExceptionType.network: l10n.failureNetwork,
      AppExceptionType.auth: l10n.failureAuth,
      AppExceptionType.database: l10n.failureServer,
      AppExceptionType.streaming: l10n.failureStreaming,
      AppExceptionType.validation: l10n.failureValidation,
      AppExceptionType.realtime: l10n.failureUnknown,
      AppExceptionType.system: l10n.failureUnknown,
      AppExceptionType.unknown: l10n.failureUnknown,
    };

    cases.forEach((type, expected) {
      test('${type.name} → translated text, never the raw message', () {
        final result = mapper.map(
          AppException(message: 'raw database text', type: type),
        );

        expect(result.message, expected);
        expect(result.type, type);
      });
    });
  });

  group('GlobalErrorMapper with login errors (REV-15)', () {
    final cases = <String, String>{
      'Invalid login credentials': l10n.authErrorInvalidCredentials,
      'Email not confirmed': l10n.authErrorEmailNotConfirmed,
      'User already exists': l10n.authErrorUserExists,
      'Signups not allowed for this instance': l10n.authErrorGeneric,
    };

    cases.forEach((supabaseText, expected) {
      test('"$supabaseText" → translated text', () {
        final wrapped = AppException(
          message: supabaseText,
          type: AppExceptionType.auth,
          originalError: AuthException(supabaseText),
        );

        expect(mapper.map(wrapped).message, expected);
        expect(mapper.map(AuthException(supabaseText)).message, expected);
      });
    });

    test('uses the Italian text for the Italian locale', () {
      final it = lookupAppLocalizations(const Locale('it'));
      final result = GlobalErrorMapper(
        it,
      ).map(AuthException('Invalid login credentials'));

      expect(result.message, it.authErrorInvalidCredentials);
    });
  });

  group('GlobalErrorMapper fallback', () {
    test('an unknown error shows the translated text, not toString()', () {
      final result = mapper.map(Exception('Invalid URL format'));

      expect(result.message, l10n.failureUnknown);
      expect(result.message, isNot(contains('Invalid URL format')));
    });
  });

  group('GlobalErrorMapper keeps the old behavior', () {
    test('a known StreamingException gets its translated text', () {
      final result = mapper.map(CapabilityMissingException('anime'));

      expect(result.message, l10n.streamingErrorCapabilityMissing('anime'));
      expect(result.type, AppExceptionType.streaming);
    });

    test('other StreamingExceptions show their own message', () {
      final result = mapper.map(StreamResolutionFailedException('timeout'));

      expect(result.message, 'Stream resolution failed: timeout');
      expect(result.type, AppExceptionType.streaming);
    });

    test('a plain string is shown as is', () {
      expect(mapper.map('plain').message, 'plain');
    });
  });
}
