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

  /// Marked true if the link failed during the current session.
  bool isFailed;

  /// How many times we've retried this link in its current pass without success.
  int softRetryCount;

  StreamLink({
    required this.url,
    this.quality = StreamQuality.sd,
    this.codec,
    this.provider,
    this.isFailed = false,
    this.softRetryCount = 0,
  });

  /// Inferred human-friendly display label for this source.
  String get displayProvider {
    if (provider != null && provider!.trim().isNotEmpty) {
      return provider!.trim();
    }
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('.ts') ||
        lowerUrl.contains('sasa24') ||
        lowerUrl.contains('maxgold') ||
        lowerUrl.contains(':8080') ||
        lowerUrl.contains(':8000')) {
      return 'IPTV 1080p';
    }
    if (lowerUrl.contains('dlhd') ||
        lowerUrl.contains('live-tv-resolver/stream')) {
      return 'CDN Fallback';
    }
    if (lowerUrl.contains('mediapolis.rai.it') || lowerUrl.contains('rai')) {
      return 'Rai Direct';
    }
    if (lowerUrl.contains('mediaset.net')) {
      return 'Mediaset Direct';
    }
    if (lowerUrl.contains('sky.it')) {
      return 'Sky Clear Feed';
    }
    return 'Direct Stream';
  }

  /// Inferred stream protocol / container.
  String get formatLabel {
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('.ts') || lowerUrl.contains('format=ts')) {
      return 'MPEG-TS';
    }
    if (lowerUrl.contains('.m3u8') || lowerUrl.contains('hls')) {
      return 'HLS';
    }
    if (lowerUrl.contains('.mpd') || lowerUrl.contains('dash')) {
      return 'DASH';
    }
    return 'Stream';
  }

  factory StreamLink.fromJson(Map<String, dynamic> json) {
    // Support both flat format (quality/codec/provider at root) and nested
    final metadata = json['metadata'] as Map<String, dynamic>?;
    final qualityStr =
        json['quality'] as String? ?? metadata?['quality'] as String?;
    final codecStr = json['codec'] as String? ?? metadata?['codec'] as String?;
    final providerStr =
        json['provider'] as String? ?? metadata?['provider'] as String?;

    return StreamLink(
      url: json['url'] as String,
      quality: StreamQuality.fromString(qualityStr),
      codec: (codecStr?.isNotEmpty ?? false) ? codecStr : null,
      provider: (providerStr?.isNotEmpty ?? false) ? providerStr : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'quality': quality.label,
    if (codec != null) 'codec': codec,
    if (provider != null) 'provider': provider,
  };

  @override
  String toString() =>
      'StreamLink(url: $url, quality: $quality, provider: $provider, codec: $codec, failed: $isFailed)';
}
