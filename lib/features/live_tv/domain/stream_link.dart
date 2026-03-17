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
  
  /// Marked true if the link failed during the current session.
  bool isFailed;

  /// Marked true if we already attempted a soft-retry for this link in its current pass.
  bool softRetryDone;

  StreamLink({
    required this.url,
    this.quality = StreamQuality.sd,
    this.codec,
    this.isFailed = false,
    this.softRetryDone = false,
  });

  factory StreamLink.fromJson(Map<String, dynamic> json) {
    return StreamLink(
      url: json['url'] as String,
      quality: StreamQuality.fromString(json['metadata']?['quality'] as String?),
      codec: json['metadata']?['codec'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'quality': quality.label,
    if (codec != null) 'codec': codec,
  };

  @override
  String toString() => 'StreamLink(url: $url, quality: $quality, codec: $codec, failed: $isFailed)';
}
