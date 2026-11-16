import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final mapper = GlobalErrorMapper(l10n);

  group('GlobalErrorMapper with AppFailure', () {
    final cases = <AppFailure, (String, ErrorKind)>{
      const NetworkFailure('dev text'): (
        l10n.failureNetwork,
        ErrorKind.network,
      ),
      const AuthFailure('dev text'): (l10n.failureAuth, ErrorKind.auth),
      const ServerFailure('dev text', statusCode: 500): (
        l10n.failureServer,
        ErrorKind.server,
      ),
      const NotFoundFailure('dev text'): (
        l10n.failureNotFound,
        ErrorKind.unknown,
      ),
      const StreamingFailure('dev text'): (
        l10n.failureStreaming,
        ErrorKind.streaming,
      ),
      const ValidationFailure('dev text'): (
        l10n.failureValidation,
        ErrorKind.validation,
      ),
      const UnknownFailure('dev text'): (
        l10n.failureUnknown,
        ErrorKind.unknown,
      ),
    };

    cases.forEach((failure, expected) {
      test('${failure.runtimeType} → translated text and icon type', () {
        final result = mapper.map(failure);

        expect(result.message, expected.$1);
        expect(result.kind, expected.$2);
        // The developer message must never reach the user (REV-164).
        expect(result.message, isNot(contains('dev text')));
      });
    });

    test('an add-on error video says why the debrid gave no file', () {
      final texts = {
        for (final reason in DebridRefusal.values)
          reason: mapper.map(DebridFileFailure(reason, 'dev text')).message,
      };

      expect(texts, {
        DebridRefusal.downloading:
            'Your debrid service is still downloading this one. '
            'Try again later.',
        DebridRefusal.copyright:
            'Your debrid service refuses this file (copyright).',
        DebridRefusal.limit:
            'Your debrid service has too many downloads running, or the '
            'account reached a limit.',
        DebridRefusal.other:
            'The source sent an error video instead of the video.',
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

    // REV-347: Riverpod wraps the failure of a provider read by another
    // one, which showed "Something went wrong".
    test('a failure passed on by another provider keeps its text', () {
      final container = ProviderContainer(retry: noProviderRetry);
      addTearDown(container.dispose);
      final source = Provider<int>(
        (ref) => throw const NetworkFailure('dev text'),
      );
      final screen = Provider<int>((ref) => ref.watch(source));
      Object? error;
      try {
        container.read(screen);
      } catch (e) {
        error = e;
      }

      final result = mapper.map(error!);

      expect(result.message, l10n.failureNetwork);
      expect(result.kind, ErrorKind.network);
    });
  });

  test('no streams: each reason gets its translated text', () {
    final texts = {
      for (final reason in NoStreamsReason.values)
        reason: mapper.map(NoStreamsFailure(reason, 'dev text')),
    };

    expect(texts.map((reason, e) => MapEntry(reason, e.message)), {
      NoStreamsReason.noAddons: l10n.streamingErrorNoProviders,
      NoStreamsReason.noDetails: l10n.streamingErrorMediaDetails,
      NoStreamsReason.noResults: l10n.streamingErrorNoResults,
      NoStreamsReason.linkFailed: l10n.streamingErrorResolutionFailed,
    });
    for (final e in texts.values) {
      expect(e.kind, ErrorKind.streaming);
    }
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
        // As the sign-in throws it.
        final wrapped = AuthFailure(
          supabaseText,
          cause: AuthException(supabaseText),
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

  group('GlobalErrorMapper other errors', () {
    test('a plain string is shown as is', () {
      expect(mapper.map('plain').message, 'plain');
    });
  });
}
