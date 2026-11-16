import 'package:cinemuse_app/features/profile/domain/agenda_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgendaEvent release dates', () {
    test('a full date is a normal event', () {
      final event = AgendaEvent.fromMovie({
        'id': 1,
        'release_date': '2026-11-20',
      });

      expect(event.releaseDate, DateTime(2026, 11, 20));
      expect(event.isTbd, isFalse);
    });

    test('a year only is TBD at the end of that year', () {
      final event = AgendaEvent.fromEpisode(
        seriesId: 2,
        seriesName: 'Show',
        seriesPosterPath: null,
        epJson: {'air_date': '2027', 'season_number': 1, 'episode_number': 1},
      );

      expect(event.releaseDate, DateTime(2027, 12, 31));
      expect(event.isTbd, isTrue);
      expect(event.customReleaseDate, '2027');
    });

    test('no date is TBD far in the future', () {
      final event = AgendaEvent.fromMovie({'id': 1, 'release_date': ''});

      expect(event.releaseDate, DateTime(2099, 12, 31));
      expect(event.isTbd, isTrue);
      expect(event.customReleaseDate, isNull);
    });
  });
}
