import 'package:cinemuse_app/features/streaming/sources/video_page_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VideoPageParser (REV-28)', () {
    // The page the movie source ends on: the params come before the address.
    const moviePage = '''
      <html><body><script>
        window.masterPlaylist = {
          params: {
            'token': 'tok',
            'expires': '123'
          },
          url: 'https://movies.example/playlist/123?b=1'
        };
      </script></body></html>
    ''';

    // The page the anime source ends on: the address also as masterPlaylistUrl.
    const animePage = '''
      <script>var other = { url: 'https://example.com/not-this' };</script>
      <script>
        window.masterPlaylistUrl = 'https://videos.example/playlist/1234';
        window.canPlayFHD = true;
        window.masterPlaylist = {
          url: 'https://videos.example/playlist/1234',
          params: { token: 'tok', expires: '456' }
        };
      </script>
    ''';

    final cases = [
      (
        name: 'movie page, always full HD',
        html: moviePage,
        alwaysFhd: true,
        addM3u8: false,
        expected:
            'https://movies.example/playlist/123?b=1&token=tok&expires=123&h=1',
      ),
      (
        name: 'movie page, full HD only when offered',
        html: moviePage,
        alwaysFhd: false,
        addM3u8: false,
        expected:
            'https://movies.example/playlist/123?b=1&token=tok&expires=123',
      ),
      (
        name: 'anime page, full HD offered, .m3u8 added',
        html: animePage,
        alwaysFhd: false,
        addM3u8: true,
        expected:
            'https://videos.example/playlist/1234.m3u8?token=tok&expires=456&h=1',
      ),
      (
        name: 'query kept when .m3u8 is added',
        html: moviePage,
        alwaysFhd: false,
        addM3u8: true,
        expected:
            'https://movies.example/playlist/123.m3u8?b=1&token=tok&expires=123',
      ),
    ];

    for (final c in cases) {
      test(c.name, () {
        final playlist = VideoPageParser.parse(c.html);
        expect(
          playlist?.playlistUrl(alwaysFhd: c.alwaysFhd, addM3u8: c.addM3u8),
          c.expected,
        );
      });
    }

    for (final html in [
      '<html>No tokens here</html>',
      "<script>window.masterPlaylist = { url: 'https://a.b/p', "
          "params: { expires: '1' } };</script>",
    ]) {
      test('a page without address, token or expiry gives nothing', () {
        expect(VideoPageParser.parse(html), isNull);
      });
    }
  });
}
