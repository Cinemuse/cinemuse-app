import 'package:cinemuse_app/features/live_tv/domain/stream_address.dart';

/// Quality levels for IPTV streams.
enum StreamQuality {
  sd('SD'),
  hd('HD'),
  fhd('FHD'),
  uhd('4K');

  final String label;
  const StreamQuality(this.label);

  static StreamQuality fromString(String? quality) {
    if (quality == null) return StreamQuality.sd;
    switch (quality.toUpperCase()) {
      case '4K':
      case 'UHD':
        return StreamQuality.uhd;
      case 'FHD':
      case 'FULL HD':
        return StreamQuality.fhd;
      case 'HD':
        return StreamQuality.hd;
      default:
        return StreamQuality.sd;
    }
  }
}

/// A specific stream source for a channel.
class StreamLink {
  final String url;
  final StreamQuality quality;
  final String? codec;
  final String? provider;

  /// The broadcaster to ask for the real stream address at play time
  /// (`cinemuse-ask` in the playlist, e.g. "sky"): [url] is then its lookup
  /// address, not a stream.
  final String? ask;

  /// Headers the playlist asks to send with this stream (a Referer or a
  /// User-Agent some servers check), names as in [headerName].
  final Map<String, String> headers;

  /// Marked true if the link failed during the current session.
  bool isFailed;

  /// How many times we've retried this link in its current pass without success.
  int softRetryCount;

  StreamLink({
    required this.url,
    this.quality = StreamQuality.sd,
    this.codec,
    this.provider,
    this.ask,
    this.headers = const {},
    this.isFailed = false,
    this.softRetryCount = 0,
  });

  /// The source's name in the player: the playlist's own, else the
  /// broadcaster its address belongs to, else the address's site.
  String get displayProvider {
    if (provider != null && provider!.trim().isNotEmpty) {
      return provider!.trim();
    }
    if (ask == 'rai') return 'Rai';
    if (ask == 'sky') return 'Sky';
    final address = StreamAddress(url);
    if (address.isOn('rai.it')) return 'Rai';
    if (address.isOn('mediaset.net')) return 'Mediaset';
    if (address.isOn('sky.it')) return 'Sky';
    return address.host.isEmpty ? 'Stream' : address.host;
  }

  /// One spelling per header, so a playlist's "referrer" or "user-agent"
  /// replaces the app's own "Referer" or "User-Agent" instead of sending
  /// both.
  static String headerName(String name) {
    final trimmed = name.trim();
    switch (trimmed.toLowerCase()) {
      case 'referer':
      case 'referrer':
      case 'http-referrer':
      case 'http-referer':
        return 'Referer';
      case 'user-agent':
      case 'http-user-agent':
        return 'User-Agent';
      case 'origin':
      case 'http-origin':
        return 'Origin';
      default:
        return trimmed;
    }
  }

  factory StreamLink.fromJson(Map<String, dynamic> json) {
    // Support both flat format (quality/codec/provider at root) and nested
    final metadata = json['metadata'] as Map<String, dynamic>?;
    final qualityStr =
        json['quality'] as String? ?? metadata?['quality'] as String?;
    final codecStr = json['codec'] as String? ?? metadata?['codec'] as String?;
    final providerStr =
        json['provider'] as String? ?? metadata?['provider'] as String?;
    final headersJson = json['headers'];

    return StreamLink(
      url: json['url'] as String,
      quality: StreamQuality.fromString(qualityStr),
      codec: (codecStr?.isNotEmpty ?? false) ? codecStr : null,
      provider: (providerStr?.isNotEmpty ?? false) ? providerStr : null,
      headers: {
        if (headersJson is Map)
          for (final entry in headersJson.entries)
            if (entry.key is String &&
                entry.value is String &&
                (entry.value as String).isNotEmpty)
              headerName(entry.key as String): entry.value as String,
      },
    );
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'quality': quality.label,
    if (codec != null) 'codec': codec,
    if (provider != null) 'provider': provider,
    if (headers.isNotEmpty) 'headers': headers,
  };

  @override
  String toString() =>
      'StreamLink(url: $url, quality: $quality, provider: $provider, codec: $codec, failed: $isFailed)';
}
