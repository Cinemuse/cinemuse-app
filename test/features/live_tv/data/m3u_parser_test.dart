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
}
