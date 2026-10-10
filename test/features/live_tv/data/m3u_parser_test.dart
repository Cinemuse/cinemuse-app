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
}
