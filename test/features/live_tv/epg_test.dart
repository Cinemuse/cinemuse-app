import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/features/live_tv/data/epg_parser.dart';
import 'package:cinemuse_app/features/live_tv/data/epg_channel_matcher.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';

void main() {
  group('EpgParser', () {
    test('parses JSON format matching Cinemuse edge function', () {
      final now = DateTime.now();
      final startMs = now
          .subtract(const Duration(minutes: 15))
          .millisecondsSinceEpoch;
      final endMs = now.add(const Duration(minutes: 45)).millisecondsSinceEpoch;

      final jsonPayload = {
        'rai1': [
          {
            'name': 'TG1 Sera',
            'subtitle': 'Edizione 20:00',
            'description': 'Telegiornale a cura della redazione del TG1',
            'startTime': {'unix': startMs},
            'endTime': {'unix': endMs},
            'image': 'https://image.png',
          },
        ],
        'sportitalia': [
          {
            'name': 'Sportitalia Mercato',
            'subtitle': null,
            'description': 'Calciomercato live',
            'startTime': {'unix': startMs},
            'endTime': {'unix': endMs},
            'image': null,
          },
        ],
      };

      final parsed = EpgParser.parseJson(jsonPayload);

      expect(parsed.containsKey('rai1'), isTrue);
      expect(parsed['rai1']!.length, 1);
      final p1 = parsed['rai1']!.first;
      expect(p1.name, 'TG1 Sera');
      expect(p1.subtitle, 'Edizione 20:00');
      expect(p1.description, 'Telegiornale a cura della redazione del TG1');
      expect(p1.imageUrl, 'https://image.png');
      expect(p1.isLive, isTrue);

      expect(parsed.containsKey('sportitalia'), isTrue);
      expect(parsed['sportitalia']!.first.name, 'Sportitalia Mercato');
    });

    test('parses XMLTV string and extracts program entries', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <programme start="20261003120000 +0200" stop="20261003130000 +0200" channel="rai1">
    <title lang="it">TG1 13:00</title>
    <sub-title lang="it">Notiziario</sub-title>
    <desc lang="it">Il notiziario del primo canale Rai.</desc>
    <icon src="https://img.rai.it/tg1.jpg"/>
  </programme>
  <programme start="20261003130000 +0200" stop="20261003140000 +0200" channel="rai1">
    <title lang="it">Linea Verde</title>
  </programme>
</tv>''';

      final parsed = EpgParser.parseXmltv(xml);

      expect(parsed.containsKey('rai1'), isTrue);
      expect(parsed['rai1']!.length, 2);
      expect(parsed['rai1']![0].name, 'TG1 13:00');
      expect(parsed['rai1']![0].subtitle, 'Notiziario');
      expect(
        parsed['rai1']![0].description,
        'Il notiziario del primo canale Rai.',
      );
      expect(parsed['rai1']![0].imageUrl, 'https://img.rai.it/tg1.jpg');
      expect(parsed['rai1']![1].name, 'Linea Verde');
    });

    test('parses gzipped bytes correctly', () {
      final jsonStr = json.encode({
        'c5': [
          {
            'name': 'TG5',
            'startTime': {'unix': 1700000000000},
            'endTime': {'unix': 1700003600000},
          },
        ],
      });

      final uncompressedBytes = utf8.encode(jsonStr);
      final gzipped = GZipEncoder().encode(uncompressedBytes);

      final parsed = EpgParser.parseBytes(Uint8List.fromList(gzipped!));
      expect(parsed.containsKey('c5'), isTrue);
      expect(parsed['c5']!.first.name, 'TG5');
    });

    test('parseXmltvDate correctly parses timezone offsets', () {
      final date = EpgParser.parseXmltvDate('20261003120000 +0200');
      expect(date, isNotNull);
      final utc = date!.toUtc();
      expect(utc.hour, 10);
      expect(utc.year, 2026);
      expect(utc.month, 10);
      expect(utc.day, 3);
    });

    test('reads the timezone without a space or with a colon (LTV-04)', () {
      for (final text in [
        '20261003120000+0200',
        '20261003120000 +02:00',
        '20261003120000+02:00',
      ]) {
        expect(EpgParser.parseXmltvDate(text)!.toUtc().hour, 10, reason: text);
      }
      expect(
        EpgParser.parseXmltvDate('20261003120000-0130')!.toUtc(),
        DateTime.utc(2026, 10, 3, 13, 30),
      );
    });

    test('decodes XML entities once, numeric ones too (LTV-05)', () {
      const xml = '''<tv>
<programme start="20261003120000 +0000" stop="20261003130000 +0000" channel="c1">
<title>Caff&#232; &amp; Tom&#x2019;s &amp;lt;b&amp;gt;</title>
<desc>&#99999999; &bogus; &lt;ok&gt;</desc>
</programme>
</tv>''';

      final program = EpgParser.parseXmltv(xml)['c1']!.single;

      expect(program.name, 'Caffè & Tom’s &lt;b&gt;');
      expect(program.description, '&#99999999; &bogus; <ok>');
    });

    test('reads CDATA text and attributes in single quotes', () {
      const xml = '''<tv>
<programme start='20261003120000 +0000' stop='20261003130000 +0000' channel='c1'>
<title><![CDATA[Il Commissario Montalbano]]></title>
<desc>Prima <![CDATA[<b>visione</b>]]></desc>
<icon src='https://img/x.jpg'/>
</programme>
</tv>''';

      final program = EpgParser.parseXmltv(xml)['c1']!.single;

      expect(program.name, 'Il Commissario Montalbano');
      expect(program.description, 'Prima <b>visione</b>');
      expect(program.imageUrl, 'https://img/x.jpg');
    });

    test('skips a programme the guide has commented out', () {
      const xml = '''<tv>
<!-- <programme start="20261003120000 +0000" stop="20261003130000 +0000" channel="c1"><title>Old</title></programme> -->
<programme start="20261003130000 +0000" stop="20261003140000 +0000" channel="c1"><title>New</title></programme>
</tv>''';

      final programs = EpgParser.parseXmltv(xml)['c1']!;

      expect(programs.map((p) => p.name), ['New']);
    });

    test('reads on after a broken spot or a programme left open', () {
      const xml = '''<tv>
<programme start="20261003120000 +0000" stop="20261003130000 +0000" channel="c1">
<title>Love <3</title>
<programme start="20261003130000 +0000" stop="20261003140000 +0000" channel="c2">
<title>After</title>
</programme>
</tv>''';

      final parsed = EpgParser.parseXmltv(xml);

      expect(parsed['c1']!.single.name, 'Love <3');
      expect(parsed['c2']!.single.name, 'After');
    });

    test('finds a channel by the names the guide gives it', () {
      const xml = '''<tv>
<channel id="Rai1.it"><display-name lang="it">RAI UNO</display-name><display-name>c2</display-name></channel>
<programme start="20261003120000 +0000" stop="20261003130000 +0000" channel="Rai1.it"><title>TG1</title></programme>
<programme start="20261003120000 +0000" stop="20261003130000 +0000" channel="c2"><title>Own</title></programme>
</tv>''';

      final parsed = EpgParser.parseXmltv(xml);

      expect(identical(parsed['rai uno'], parsed['Rai1.it']), isTrue);
      expect(identical(parsed['raiuno'], parsed['Rai1.it']), isTrue);
      // A name never takes the place of another channel's id.
      expect(parsed['c2']!.single.name, 'Own');
      const channel = Channel(lcn: 0, name: 'Rai Uno', logo: '');
      expect(
        EpgChannelMatcher.findPrograms(channel, parsed).single.name,
        'TG1',
      );
    });

    test('reads the channel numbers the Cinemuse guide sends', () {
      final parsed = EpgParser.parseJson({
        'rai1': [
          {
            'name': 'TG1',
            'startTime': {'unix': 1000},
            'endTime': {'unix': 2000},
          },
        ],
        'channels': {
          'rai1': {'name': 'Rai 1', 'lcn': 1},
          'la7cinema': {'name': 'La7 Cinema', 'lcn': 29},
        },
      });

      expect(identical(parsed['lcn:1'], parsed['rai1']), isTrue);
      // No programmes, so its number leads nowhere.
      expect(parsed.containsKey('lcn:29'), isFalse);
      expect(parsed.containsKey('channels'), isFalse);
    });
  });

  group('EpgChannelMatcher', () {
    final now = DateTime.now();
    final epgData = <String, List<EpgProgram>>{
      'rai1': [
        EpgProgram(
          name: 'Affari Tuoi',
          startTime: now.subtract(const Duration(minutes: 20)),
          endTime: now.add(const Duration(minutes: 25)),
        ),
        EpgProgram(
          name: 'Film Serale',
          startTime: now.add(const Duration(minutes: 25)),
          endTime: now.add(const Duration(hours: 2)),
        ),
      ],
      'sportitalia': [
        EpgProgram(
          name: 'SI Live 24',
          startTime: now.subtract(const Duration(minutes: 10)),
          endTime: now.add(const Duration(minutes: 30)),
        ),
      ],
      'sky_878': [
        EpgProgram(
          name: 'Ciclismo Giro di Lombardia',
          startTime: now.subtract(const Duration(minutes: 30)),
          endTime: now.add(const Duration(hours: 1)),
        ),
      ],
    };

    test('matches exact epgId', () {
      final ch = Channel(lcn: 1, name: 'Rai 1 HD', logo: '', epgId: 'rai1');
      final programs = EpgChannelMatcher.findPrograms(ch, epgData);
      expect(programs.length, 2);
      expect(programs.first.name, 'Affari Tuoi');
    });

    test(
      'matches stripped domain epgId (e.g. SPORTITALIA.ch to sportitalia)',
      () {
        final ch = Channel(
          lcn: 60,
          name: 'Sportitalia',
          logo: '',
          epgId: 'SPORTITALIA.ch',
        );
        final programs = EpgChannelMatcher.findPrograms(ch, epgData);
        expect(programs.length, 1);
        expect(programs.first.name, 'SI Live 24');
      },
    );

    test('matches by the number the guide sends when nothing else does', () {
      final withNumbers = {
        ...epgData,
        EpgParser.numberKey(1): epgData['rai1']!,
      };
      const ch = Channel(lcn: 1, name: 'RAI UNO', logo: '');
      final programs = EpgChannelMatcher.findPrograms(ch, withNumbers);
      expect(programs.first.name, 'Affari Tuoi');
    });

    test('never matches by a number the guide does not send', () {
      const ch = Channel(lcn: 210, name: 'Eurosport 1', logo: '');
      expect(EpgChannelMatcher.findPrograms(ch, epgData), isEmpty);
    });

    test('getNowAndNext returns current live program and next program', () {
      final ch = Channel(lcn: 1, name: 'Rai 1 HD', logo: '', epgId: 'rai1');
      final result = EpgChannelMatcher.getNowAndNext(ch, epgData);

      expect(result.current, isNotNull);
      expect(result.current!.name, 'Affari Tuoi');
      expect(result.next, isNotNull);
      expect(result.next!.name, 'Film Serale');
    });
  });
}
