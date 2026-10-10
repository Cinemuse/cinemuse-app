import 'package:cinemuse_app/core/error/app_exception.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/core/services/streaming/models/streaming_exceptions.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

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

  group('GlobalErrorMapper keeps the old behavior', () {
    test('AppException shows its message and type', () {
      final result = mapper.map(
        AppException(message: 'old', type: AppExceptionType.auth),
      );

      expect(result.message, 'old');
      expect(result.type, AppExceptionType.auth);
    });

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
