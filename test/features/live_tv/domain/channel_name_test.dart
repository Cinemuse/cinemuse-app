import 'package:cinemuse_app/features/live_tv/domain/channel_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChannelName.rowId', () {
    test('names that differ only by a quality word share a row', () {
      expect(ChannelName.rowId('Rai 1 HD', null), 'name:rai 1');
      expect(ChannelName.rowId('RAI 1 FHD', 'rai1.it'), 'name:rai 1');
    });

    test('channels sharing a guide keep their own rows', () {
      final ids = {
        ChannelName.rowId('Rai 3', 'Rai3.it'),
        ChannelName.rowId('Rai 3 TGR Lombardia', 'Rai3.it'),
        ChannelName.rowId('Canale 5', 'Canale5.it'),
        ChannelName.rowId('Canale 5 +1', 'Canale5.it'),
      };
      expect(ids, hasLength(4));
    });

    test('keeps the "+1" however it is spaced', () {
      expect(ChannelName.rowId('Canale 5+1', null), 'name:canale 5 +1');
      expect(ChannelName.rowId('Canale 5 + 1', null), 'name:canale 5 +1');
    });

    test('keeps accented letters', () {
      expect(ChannelName.rowId('Rai Südtirol', null), 'name:rai südtirol');
    });

    test('uses the guide id only for a channel with no name', () {
      expect(ChannelName.rowId(' HD ', ' Rai1.it '), 'epg:rai1.it');
    });
  });

  group('ChannelName guide keys', () {
    test('an id and a name give the same key', () {
      expect(ChannelName.guideKey('Rai1.it'), 'rai1');
      expect(ChannelName.guideKeysForName('Rai 1 HD'), contains('rai1'));
    });

    test('accents are dropped, so "Rai Südtirol" finds "RaiSudtirol.it"', () {
      expect(ChannelName.guideKey('RaiSudtirol.it'), 'raisudtirol');
      expect(ChannelName.guideKeysForName('Rai Südtirol'), [
        'rai südtirol',
        'raisudtirol',
      ]);
    });

    test('the exact name first, then without "Italia"', () {
      expect(ChannelName.guideKeysForName('Sky Italia News'), [
        'sky italia news',
        'skyitalianews',
        'skynews',
      ]);
    });
  });

  group('ChannelName "+1" channels', () {
    test('how many hours later', () {
      expect(ChannelName.hoursLater('Canale 5 +1'), 1);
      expect(ChannelName.hoursLater('Rete 4+2 HD'), 2);
      expect(ChannelName.hoursLater('Canale 5'), 0);
      expect(ChannelName.hoursLater('Canal+'), 0);
      expect(ChannelName.hoursLater('Rai 1'), 0);
    });

    test('the name of the channel it repeats', () {
      expect(ChannelName.withoutHoursLater('Canale 5 +1 HD'), 'canale 5');
    });

    test('a guide id that is the "+1" channel\'s own', () {
      expect(ChannelName.idIsHoursLater('Canale5+1.it'), isTrue);
      expect(ChannelName.idIsHoursLater('Canale5Plus1.it'), isTrue);
      expect(ChannelName.idIsHoursLater('Canale5.it'), isFalse);
      expect(ChannelName.idIsHoursLater('Rai1.it'), isFalse);
    });
  });
}
