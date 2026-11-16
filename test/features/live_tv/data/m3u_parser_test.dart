import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/features/live_tv/data/m3u_parser.dart';

void main() {
  group('M3uParser channel name', () {
    test('keeps a comma that is part of the name (REV-123)', () {
      const m3u = '''#EXTM3U
#EXTINF:-1 tvg-id="rai1.it" group-title="News, Italy",Rai 1, HD
http://example.com/rai1.m3u8
''';

      final channel = M3uParser.parse(m3u).single;

      expect(channel.name, 'Rai 1, HD');
      expect(channel.group, 'News, Italy');
      expect(channel.epgId, 'rai1.it');
    });

    test('reads the name when the line has no attributes', () {
      const m3u = '''#EXTM3U
#EXTINF:-1,Rai 2
http://example.com/rai2.m3u8
''';

      expect(M3uParser.parse(m3u).single.name, 'Rai 2');
    });

    test('falls back to tvg-name when there is no name after the comma', () {
      const m3u = '''#EXTM3U
#EXTINF:-1 tvg-name="Rai 3",
http://example.com/rai3.m3u8
''';

      expect(M3uParser.parse(m3u).single.name, 'Rai 3');
    });
  });

  group('M3uParser rows', () {
    test('channels sharing a guide but not a name get their own row', () {
      const m3u = '''#EXTM3U
#EXTINF:-1 tvg-id="Rai3.it",Rai 3
http://example.com/rai3.m3u8
#EXTINF:-1 tvg-id="Rai3.it",Rai 3 TGR Lombardia
http://example.com/rai3-lombardia.m3u8
#EXTINF:-1 tvg-id="Canale5.it",Canale 5
http://example.com/canale5.m3u8
#EXTINF:-1 tvg-id="Canale5.it",Canale 5 +1
http://example.com/canale5-1.m3u8
''';

      final channels = M3uParser.parse(m3u);

      expect(channels.map((c) => c.name), [
        'Rai 3',
        'Rai 3 TGR Lombardia',
        'Canale 5',
        'Canale 5 +1',
      ]);
      expect(channels.every((c) => c.links.length == 1), isTrue);
    });

    test('names that differ only by a quality word share a row', () {
      const m3u = '''#EXTM3U
#EXTINF:-1,Rai 1
http://example.com/rai1.m3u8
#EXTINF:-1,Rai 1 HD
http://example.com/rai1-hd.m3u8
''';

      final channel = M3uParser.parse(m3u).single;

      expect(channel.links.map((l) => l.url), [
        'http://example.com/rai1.m3u8',
        'http://example.com/rai1-hd.m3u8',
      ]);
    });
  });

  group('M3uParser attributes (REV-123)', () {
    test('reads attributes in any case and with single quotes', () {
      const m3u = '''#EXTM3U
#EXTINF:-1 TVG-ID='rai1.it' Tvg-Logo='http://x/logo.png' GROUP-TITLE='News, Italy',L'Equipe
http://example.com/rai1.m3u8
''';

      final channel = M3uParser.parse(m3u).single;

      expect(channel.epgId, 'rai1.it');
      expect(channel.logo, 'http://x/logo.png');
      expect(channel.group, 'News, Italy');
      expect(channel.name, "L'Equipe");
    });

    test('keeps the broadcaster to ask at play time', () {
      const m3u = '''#EXTM3U
#EXTINF:-1 tvg-id="tv8" cinemuse-ask="sky",TV8
https://example.com/getLivestream?id=7
#EXTINF:-1 tvg-id="la7",La7
https://example.com/la7.m3u8
''';

      final channels = M3uParser.parse(m3u);

      expect(channels[0].links.single.ask, 'sky');
      expect(channels[1].links.single.ask, isNull);
    });

    test('does not read an attribute from inside a longer name', () {
      const m3u = '''#EXTM3U
#EXTINF:-1 x-tvg-id="wrong",Rai 1
http://example.com/rai1.m3u8
''';

      expect(M3uParser.parse(m3u).single.epgId, isNull);
    });

    test('uses #EXTGRP when there is no group-title', () {
      const m3u = '''#EXTM3U
#EXTINF:-1,Sky Sport
#EXTGRP:Sport
http://example.com/sport.m3u8
#EXTINF:-1 group-title="News",Rai News
#EXTGRP:Sport
http://example.com/news.m3u8
#EXTINF:-1,Rai 2
http://example.com/rai2.m3u8
''';

      final channels = M3uParser.parse(m3u);

      expect(channels.map((c) => c.group), ['Sport', 'News', null]);
    });
  });

  group('M3uParser per-channel headers', () {
    test('reads #EXTVLCOPT lines, before or after #EXTINF', () {
      const m3u = '''#EXTM3U
#EXTVLCOPT:http-user-agent=Agent/1.0
#EXTINF:-1,A
#EXTVLCOPT:http-referrer=https://page.example/
#EXTVLCOPT:network-caching=1000
http://example.com/a.m3u8
''';

      expect(M3uParser.parse(m3u).single.links.single.headers, {
        'User-Agent': 'Agent/1.0',
        'Referer': 'https://page.example/',
      });
    });

    test('reads an #EXTHTTP line; a broken one loses only its headers', () {
      const m3u = '''#EXTM3U
#EXTINF:-1,A
#EXTHTTP:{"Referer":"https://page.example/","Origin":"https://page.example"}
http://example.com/a.m3u8
#EXTINF:-1,B
#EXTHTTP:{not json
http://example.com/b.m3u8
''';

      final channels = M3uParser.parse(m3u);

      expect(channels.first.links.single.headers, {
        'Referer': 'https://page.example/',
        'Origin': 'https://page.example',
      });
      expect(channels.last.links.single.headers, isEmpty);
      expect(channels.last.url, 'http://example.com/b.m3u8');
    });

    test('reads the tail after "|" and drops it from the address', () {
      const m3u = '''#EXTM3U
#EXTINF:-1,A
http://example.com/a.m3u8|Referer=https://page.example/&User-Agent=Mozilla%2F5.0
''';

      final link = M3uParser.parse(m3u).single.links.single;

      expect(link.url, 'http://example.com/a.m3u8');
      expect(link.headers, {
        'Referer': 'https://page.example/',
        'User-Agent': 'Mozilla/5.0',
      });
    });

    test('a channel\'s headers don\'t carry over to the next one', () {
      const m3u = '''#EXTM3U
#EXTINF:-1,A
#EXTVLCOPT:http-referrer=https://page.example/
http://example.com/a.m3u8
#EXTINF:-1,B
http://example.com/b.m3u8
''';

      expect(M3uParser.parse(m3u).last.links.single.headers, isEmpty);
    });
  });
}
