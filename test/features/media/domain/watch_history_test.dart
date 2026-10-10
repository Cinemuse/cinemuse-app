import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WatchLog times (REV-178)', () {
    test('an optimistic log matches the saved one from the server', () {
      // The app adds "now" in local time; the server sends it back in UTC.
      final appTime = DateTime.utc(2026, 10, 9, 18, 0, 5, 123).toLocal();
      final saved = WatchLog.fromJson({
        'tmdb_id': 1399,
        'media_type': 'movie',
        'logged_at': '2026-10-09T18:00:05.123456+00:00',
      });

      expect(
        WatchLog.timestampKey(appTime),
        WatchLog.timestampKey(saved.loggedAt),
      );
    });

    test('logged_at from the server is shown in local time', () {
      final log = WatchLog.fromJson({
        'tmdb_id': 1399,
        'media_type': 'movie',
        'logged_at': '2026-10-09T22:00:00+00:00',
      });

      expect(log.loggedAt.isUtc, isFalse);
      expect(
        log.loggedAt.isAtSameMomentAs(DateTime.utc(2026, 10, 9, 22)),
        isTrue,
      );
    });
  });
}
