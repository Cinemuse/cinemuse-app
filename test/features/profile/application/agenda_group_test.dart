import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/profile/application/agenda_providers.dart';
import 'package:cinemuse_app/features/profile/domain/agenda_event.dart';
import 'package:flutter_test/flutter_test.dart';

AgendaEvent _event(String id, DateTime date, {bool isTbd = false}) =>
    AgendaEvent(
      id: id,
      tmdbId: 1,
      title: id,
      releaseDate: date,
      isTbd: isTbd,
      type: MediaKind.movie,
    );

Map<AgendaGroup, List<String>> _ids(GroupedAgenda groups) => {
  for (final entry in groups.entries)
    entry.key: [for (final e in entry.value) e.id],
};

void main() {
  test('groups by calendar day and Monday-to-Sunday weeks', () {
    // Wednesday 14 October 2026.
    final now = DateTime(2026, 10, 14, 18, 30);
    final groups = groupEvents([
      _event('too-old', DateTime(2026, 9, 13)),
      _event('recent', DateTime(2026, 9, 14)),
      _event('yesterday', DateTime(2026, 10, 13)),
      _event('today', DateTime(2026, 10, 14)),
      _event('tomorrow', DateTime(2026, 10, 15)),
      _event('sunday', DateTime(2026, 10, 18, 23, 59, 59)),
      _event('next-monday', DateTime(2026, 10, 19)),
      _event('next-sunday', DateTime(2026, 10, 25, 23, 59, 59)),
      _event('later', DateTime(2026, 10, 26)),
      _event('tbd', DateTime(2099, 12, 31), isTbd: true),
    ], now: now);

    expect(_ids(groups), {
      AgendaGroup.recentlyReleased: ['recent', 'yesterday'],
      AgendaGroup.today: ['today'],
      AgendaGroup.tomorrow: ['tomorrow'],
      AgendaGroup.thisWeek: ['sunday'],
      AgendaGroup.nextWeek: ['next-monday', 'next-sunday'],
      AgendaGroup.later: ['later'],
      AgendaGroup.tbd: ['tbd'],
    });
  });

  // The two days the clocks change in Italy (25 and 23 hours long). The bug
  // only shows in a time zone with daylight saving time.
  for (final changeDay in [DateTime(2026, 10, 25), DateTime(2027, 3, 28)]) {
    test('tomorrow is right on the clock change day $changeDay', () {
      final now = changeDay.add(const Duration(hours: 10));
      final nextDay = DateTime(
        changeDay.year,
        changeDay.month,
        changeDay.day + 1,
      );
      final groups = groupEvents([_event('next-day', nextDay)], now: now);

      expect(_ids(groups), {
        AgendaGroup.tomorrow: ['next-day'],
      });
    });
  }
}
