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

    test('finds "RaiSudtirol.it" for "Rai Südtirol"', () {
      const channel = Channel(lcn: 0, name: 'Rai Südtirol', logo: '');
      final epg = {
        'raisudtirol': [program],
      };

      expect(EpgChannelMatcher.findPrograms(channel, epg), [program]);
    });
  });

  group('EpgChannelMatcher "+1" channels', () {
    test('a "+1" channel on the normal channel\'s guide id airs an hour '
        'later', () {
      const channel = Channel(
        lcn: 0,
        name: 'Canale 5 +1',
        logo: '',
        epgId: 'Canale5.it',
      );
      final epg = {
        'Canale5.it': [program],
      };

      final shifted = EpgChannelMatcher.findPrograms(channel, epg).single;

      expect(shifted.name, 'News');
      expect(shifted.startTime, DateTime(2026, 10, 12, 21));
      expect(shifted.endTime, DateTime(2026, 10, 12, 22));
    });

    test('gives back the same shifted list each time', () {
      const channel = Channel(
        lcn: 0,
        name: 'Canale 5 +1',
        logo: '',
        epgId: 'Canale5.it',
      );
      final epg = {
        'Canale5.it': [program],
      };

      expect(
        identical(
          EpgChannelMatcher.findPrograms(channel, epg),
          EpgChannelMatcher.findPrograms(channel, epg),
        ),
        isTrue,
      );
    });

    test('a "+2" channel found by the normal name airs two hours later', () {
      const channel = Channel(lcn: 0, name: 'Rete 4 +2', logo: '');
      final epg = {
        'rete4': [program],
      };

      final shifted = EpgChannelMatcher.findPrograms(channel, epg).single;

      expect(shifted.startTime, DateTime(2026, 10, 12, 22));
    });

    test('a "+1" channel with its own guide keeps its times', () {
      const byId = Channel(
        lcn: 0,
        name: 'Canale 5 +1',
        logo: '',
        epgId: 'Canale5+1.it',
      );
      const byName = Channel(lcn: 0, name: 'Canale 5 +1', logo: '');
      final epg = {
        'Canale5+1.it': [program],
        'canale51': [program],
      };

      expect(EpgChannelMatcher.findPrograms(byId, epg), [program]);
      expect(EpgChannelMatcher.findPrograms(byName, epg), [program]);
    });

    test('the normal channel keeps its times', () {
      const channel = Channel(
        lcn: 0,
        name: 'Canale 5',
        logo: '',
        epgId: 'Canale5.it',
      );
      final epg = {
        'Canale5.it': [program],
      };

      expect(EpgChannelMatcher.findPrograms(channel, epg), [program]);
    });
  });
}
