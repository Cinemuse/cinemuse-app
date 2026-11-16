/// What the app reads from a live link: only its parts (site, port, path,
/// query), never words found anywhere in it. A token like "strain42" in a
/// query must not make a link look like Rai's.
class StreamAddress {
  final Uri? _uri;

  StreamAddress(String url) : _uri = Uri.tryParse(url.trim());

  /// The site, lower case, without "www."; empty when the link has none.
  String get host {
    final host = _uri?.host.toLowerCase() ?? '';
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  String get _path => _uri?.path.toLowerCase() ?? '';

  /// True when the site is [domain] or one of its subdomains.
  bool isOn(String domain) => host == domain || host.endsWith('.$domain');

  /// Rai's lookup address, which answers with the real stream address.
  bool get isRaiRelinker =>
      isOn('mediapolis.rai.it') && _path.startsWith('/relinker');

  /// An Xtream server's channel address (`/live/<user>/<pass>/<id>.ts`).
  bool get isXtream => _uri?.pathSegments.contains('live') ?? false;

  /// A raw TV stream rather than an HLS playlist: a `.ts` file, an Xtream
  /// `extension=ts` link, or a portal's `live.php?mac=` link.
  bool get isRawTs {
    final query = _uri?.queryParameters ?? const {};
    return _path.endsWith('.ts') ||
        query['extension']?.toLowerCase() == 'ts' ||
        (_path.endsWith('/live.php') && query.containsKey('mac'));
  }

  /// An Xtream link that its server redirects to the real stream.
  bool get isXtreamRedirect =>
      isXtream && (_path.endsWith('.ts') || _path.endsWith('.m3u8'));
}
