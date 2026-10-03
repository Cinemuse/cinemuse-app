import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/features/live_tv/data/epg_parser.dart';
import 'package:cinemuse_app/features/live_tv/data/epg_channel_matcher.dart';
import 'package:cinemuse_app/features/live_tv/data/m3u_parser.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';

void main() {
  group('EpgParser', () {
    test('parses JSON format matching Cinemuse edge function', () {
      final now = DateTime.now();
      final startMs = now.subtract(const Duration(minutes: 15)).millisecondsSinceEpoch;
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
          }
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
      expect(parsed['rai1']![0].description, 'Il notiziario del primo canale Rai.');
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
          }
        ]
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
      'dlhd_878': [
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

    test('matches stripped domain epgId (e.g. SPORTITALIA.ch to sportitalia)', () {
      final ch = Channel(lcn: 60, name: 'Sportitalia', logo: '', epgId: 'SPORTITALIA.ch');
      final programs = EpgChannelMatcher.findPrograms(ch, epgData);
      expect(programs.length, 1);
      expect(programs.first.name, 'SI Live 24');
    });

    test('matches by LCN fallback when epgId is missing', () {
      // LCN 210 maps to Eurosport 1 (dlhd_878)
      final ch = Channel(lcn: 210, name: 'Eurosport 1', logo: '', epgId: null);
      final programs = EpgChannelMatcher.findPrograms(ch, epgData);
      expect(programs.length, 1);
      expect(programs.first.name, 'Ciclismo Giro di Lombardia');
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

  group('M3uParser.extractEpgUrl', () {
    test('extracts url-tvg from header', () {
      const m3u = '#EXTM3U url-tvg="https://example.com/epg.xml.gz" x-tvg-url="https://example.com/epg.xml.gz"\n#EXTINF:-1,Channel 1\nhttp://stream';
      final url = M3uParser.extractEpgUrl(m3u);
      expect(url, 'https://example.com/epg.xml.gz');
    });

    test('extracts x-tvg-url when url-tvg is absent', () {
      const m3u = '#EXTM3U x-tvg-url="https://example.com/tvguide.json"\n#EXTINF:-1,Channel 1\nhttp://stream';
      final url = M3uParser.extractEpgUrl(m3u);
      expect(url, 'https://example.com/tvguide.json');
    });

    test('returns null if no header attributes exist', () {
      const m3u = '#EXTM3U\n#EXTINF:-1,Channel 1\nhttp://stream';
      final url = M3uParser.extractEpgUrl(m3u);
      expect(url, isNull);
    });
  });
}
