import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreamLink.displayProvider', () {
    test('the playlist\'s own name comes first', () {
      expect(
        StreamLink(
          url: 'https://a.rai.it/x',
          provider: ' Mine ',
        ).displayProvider,
        'Mine',
      );
    });

    test('broadcasters are told by their address or the ask label', () {
      expect(
        StreamLink(url: 'https://mediapolis.rai.it/relinker').displayProvider,
        'Rai',
      );
      expect(
        StreamLink(url: 'https://live.mediaset.net/x.m3u8').displayProvider,
        'Mediaset',
      );
      expect(
        StreamLink(url: 'https://lookup.example/7', ask: 'sky').displayProvider,
        'Sky',
      );
    });

    // Today's guesses read words anywhere in the link.
    test('words inside the link don\'t name the source', () {
      expect(
        StreamLink(
          url: 'https://cdn.example.com/live.m3u8?token=strain42',
        ).displayProvider,
        'cdn.example.com',
      );
      expect(
        StreamLink(url: 'http://x.tsmedia.it:8080/a.m3u8').displayProvider,
        'x.tsmedia.it',
      );
    });

    test('a link with no site is just "Stream" (the same word in Italian)', () {
      expect(StreamLink(url: 'stream-7').displayProvider, 'Stream');
    });
  });

  group('StreamLink.fromJson', () {
    test('reads the link\'s headers, one spelling per header', () {
      final link = StreamLink.fromJson({
        'url': 'https://a/x.m3u8',
        'headers': {
          'referrer': 'https://page.example/',
          'user-agent': 'X',
          'bad': 3,
          'empty': '',
        },
      });

      expect(link.headers, {
        'Referer': 'https://page.example/',
        'User-Agent': 'X',
      });
      expect(StreamLink.fromJson(link.toJson()).headers, link.headers);
    });

    test('a link without headers has none', () {
      expect(StreamLink.fromJson({'url': 'https://a/x.m3u8'}).headers, isEmpty);
    });
  });
}
