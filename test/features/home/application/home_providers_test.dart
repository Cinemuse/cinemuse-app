import 'package:cinemuse_app/features/home/application/home_providers.dart';
import 'package:cinemuse_app/features/home/domain/sport_tv_event.dart';
import 'package:flutter_test/flutter_test.dart';

SportTvEvent _event(String name, DateTime? at) => SportTvEvent(
  dateTime: at,
  sportName: name,
  description: '',
  channels: const [],
);

void main() {
  group('upcomingSportEvents', () {
    final now = DateTime(2026, 10, 11, 20);

    test('drops events that started more than 3 hours ago', () {
      final result = upcomingSportEvents([
        _event('yesterday', DateTime(2026, 10, 10, 21)),
        _event('long ago today', DateTime(2026, 10, 11, 16, 59)),
        _event('still on', DateTime(2026, 10, 11, 18)),
        _event('later', DateTime(2026, 10, 11, 22)),
      ], now);

      expect(result.map((e) => e.sportName), ['still on', 'later']);
    });

    test('sorts by start time and keeps events without a time last', () {
      final result = upcomingSportEvents([
        _event('no time', null),
        _event('late', DateTime(2026, 10, 12, 9)),
        _event('early', DateTime(2026, 10, 11, 21)),
      ], now);

      expect(result.map((e) => e.sportName), ['early', 'late', 'no time']);
    });
  });
}
