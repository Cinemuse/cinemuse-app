/// What a video page says about its HLS master playlist.
class VideoPagePlaylist {
  final String url;
  final String token;
  final String expires;
  final bool canPlayFHD;

  const VideoPagePlaylist({
    required this.url,
    required this.token,
    required this.expires,
    required this.canPlayFHD,
  });

  /// The playlist address with the page's token and expiry.
  ///
  /// [alwaysFhd] asks for full HD even when the page doesn't offer it
  /// (the movie source always did). [addM3u8] ends the path with `.m3u8`
  /// (the anime source always did).
  String playlistUrl({bool alwaysFhd = false, bool addM3u8 = false}) {
    final base = Uri.parse(url);
    var path = base.path;
    if (addM3u8 && !path.endsWith('.m3u8')) {
      path = '${path.replaceAll(RegExp(r'/$'), '')}.m3u8';
    }
    return base
        .replace(
          path: path,
          queryParameters: {
            ...base.queryParameters,
            'token': token,
            'expires': expires,
            if (alwaysFhd || canPlayFHD) 'h': '1',
          },
        )
        .toString();
  }
}

/// Reads the video page that both built-in sources, movies and anime, end
/// on (REV-28).
class VideoPageParser {
  const VideoPageParser._();

  /// The playlist of [html], or null when the page has no address, token or
  /// expiry.
  static VideoPagePlaylist? parse(String html) {
    final script =
        RegExp(
          r'<script[^>]*>([\s\S]*?masterPlaylist[\s\S]*?)</script>',
        ).firstMatch(html)?.group(1) ??
        html;

    final url =
        _match(
          script,
          r'''window\.masterPlaylistUrl\s*=\s*['"]([^'"]+)['"]''',
        ) ??
        _match(script, r'''url\s*:\s*['"]([^'"]+)['"]''');
    final token = _param(script, 'token');
    final expires = _param(script, 'expires');
    if (url == null || token == null || expires == null) return null;

    return VideoPagePlaylist(
      url: url,
      token: token,
      expires: expires,
      canPlayFHD: RegExp(
        r'canPlayFHD\s*[:=]\s*true',
        caseSensitive: false,
      ).hasMatch(script),
    );
  }

  /// A `token: '…'` style entry of the playlist's params.
  static String? _param(String script, String name) =>
      _match(script, '''['"]?$name['"]?\\s*:\\s*['"]([^'"]+)['"]''');

  static String? _match(String text, String pattern) =>
      RegExp(pattern).firstMatch(text)?.group(1);
}
