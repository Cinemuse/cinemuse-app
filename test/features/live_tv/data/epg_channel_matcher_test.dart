import 'package:cinemuse_app/features/live_tv/data/epg_channel_matcher.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final program = EpgProgram(
    name: 'News',
    startTime: DateTime(2026, 10, 12, 20),
    endTime: DateTime(2026, 10, 12, 21),
  );

  group('EpgChannelMatcher.findPrograms', () {
    test('finds a guide keyed by the exact lowercase name (REV-128)', () {
      const channel = Channel(lcn: 0, name: 'Sky Italia News', logo: '');
      final epg = {
        'sky italia news': [program],
      };

      expect(EpgChannelMatcher.findPrograms(channel, epg), [program]);
    });

    test('still strips quality words from the name', () {
      const channel = Channel(lcn: 0, name: 'Rai 1 HD', logo: '');
      final epg = {
        'rai1': [program],
      };

      expect(EpgChannelMatcher.findPrograms(channel, epg), [program]);
    });

    test('prefers the tvg-id over the name', () {
      final other = EpgProgram(
        name: 'Other',
        startTime: DateTime(2026, 10, 12, 20),
        endTime: DateTime(2026, 10, 12, 21),
      );
      const channel = Channel(
        lcn: 0,
        name: 'Rai 1',
        logo: '',
        epgId: 'Rai1.it',
      );
      final epg = {
        'Rai1.it': [program],
        'rai 1': [other],
      };

      expect(EpgChannelMatcher.findPrograms(channel, epg), [program]);
    });
  });
}
