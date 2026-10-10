import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> printed;

  setUp(() {
    printed = [];
    AppLogger.sink = printed.add;
    AppLogger.minLevel = LogLevel.debug;
    AppLogger.clearRecent();
  });

  group('AppLogger.redact', () {
    test('hides user:pass in URLs', () {
      expect(
        AppLogger.redact('GET http://bob:hunter2@iptv.example.com/live'),
        'GET http://***:***@iptv.example.com/live',
      );
    });

    test('hides secret query params and keeps the others', () {
      expect(
        AppLogger.redact(
          'https://api.themoviedb.org/3/movie/1?api_key=abc123&language=it',
        ),
        'https://api.themoviedb.org/3/movie/1?api_key=***&language=it',
      );
      expect(
        AppLogger.redact('http://host/get.php?username=bob&password=pw&x=1'),
        'http://host/get.php?username=***&password=***&x=1',
      );
      expect(
        AppLogger.redact('/cb?access_token=tok&refresh_token=ref'),
        '/cb?access_token=***&refresh_token=***',
      );
    });

    test('hides Bearer tokens and JWTs', () {
      expect(
        AppLogger.redact('Authorization: Bearer abc.def-123'),
        'Authorization: Bearer ***',
      );
      expect(
        AppLogger.redact('key eyJhbGciOi.eyJzdWIiOi.SflKxwRJSM end'),
        'key *** end',
      );
    });

    test('hides key: value and JSON secrets', () {
      expect(AppLogger.redact('password: hunter2'), 'password: ***');
      expect(
        AppLogger.redact('{"token":"abc","name":"x"}'),
        '{"token":"***","name":"x"}',
      );
    });

    test('leaves normal text alone', () {
      const text = 'Loaded 12 channels from playlist "Italy" in 340 ms';
      expect(AppLogger.redact(text), text);
    });
  });

  group('AppLogger levels', () {
    test('drops lines below minLevel', () {
      AppLogger.minLevel = LogLevel.info;
      AppLogger.debug('Test', 'hidden');
      AppLogger.info('Test', 'shown');
      AppLogger.error('Test', 'also shown');

      expect(printed, hasLength(2));
      expect(AppLogger.recent.map((e) => e.message), ['shown', 'also shown']);
    });

    test('prints level, tag and the redacted message', () {
      AppLogger.warn(
        'Tmdb',
        'request failed',
        error: 'GET /movie?api_key=secret',
      );

      expect(printed.single, contains('WARN [Tmdb] request failed'));
      expect(printed.single, contains('api_key=***'));
      expect(printed.single, isNot(contains('secret')));
    });
  });

  test('keeps only the last maxRecent lines', () {
    for (var i = 0; i < AppLogger.maxRecent + 5; i++) {
      AppLogger.info('Test', 'line $i');
    }

    expect(AppLogger.recent, hasLength(AppLogger.maxRecent));
    expect(AppLogger.recent.first.message, 'line 5');
    expect(AppLogger.recent.last.message, 'line ${AppLogger.maxRecent + 4}');
  });
}
