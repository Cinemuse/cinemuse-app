import 'package:cinemuse_app/features/live_tv/domain/stream_address.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreamAddress', () {
    test('the site is read without "www." and in lower case', () {
      expect(StreamAddress('https://WWW.Example.com/a').host, 'example.com');
      expect(StreamAddress('not a link').host, '');
    });

    test('isOn matches the site and its subdomains only', () {
      final address = StreamAddress('https://live.rai.it/x.m3u8');

      expect(address.isOn('rai.it'), isTrue);
      expect(address.isOn('ai.it'), isFalse);
      expect(StreamAddress('https://a/x?from=rai.it').isOn('rai.it'), isFalse);
    });

    test('a raw stream is told by its file ending or its query', () {
      expect(StreamAddress('http://a:8080/live/u/p/1.ts').isRawTs, isTrue);
      expect(StreamAddress('http://a/get.php?extension=ts').isRawTs, isTrue);
      expect(
        StreamAddress('http://a/portal/live.php?mac=00:1A').isRawTs,
        isTrue,
      );
      expect(StreamAddress('https://a/live.m3u8?token=a.tsb').isRawTs, isFalse);
      expect(StreamAddress('https://x.tsmedia.it/live.m3u8').isRawTs, isFalse);
    });

    test('Rai\'s lookup address is told by its site and path', () {
      expect(
        StreamAddress(
          'https://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=1',
        ).isRaiRelinker,
        isTrue,
      );
      expect(
        StreamAddress(
          'https://cdn.example/x.m3u8?ref=mediapolis.rai.it/relinker',
        ).isRaiRelinker,
        isFalse,
      );
    });

    test('an Xtream link has a "live" folder in its path', () {
      expect(
        StreamAddress('http://a/live/u/p/1.m3u8').isXtreamRedirect,
        isTrue,
      );
      expect(StreamAddress('https://a/x.m3u8?path=/live/').isXtream, isFalse);
      expect(
        StreamAddress('https://a/live/index.html').isXtreamRedirect,
        isFalse,
      );
    });
  });
}
