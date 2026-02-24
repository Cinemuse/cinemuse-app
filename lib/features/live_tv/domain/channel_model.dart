/// Model representing a TV channel from zappr.stream.
class Channel {
  final int lcn;
  final String name;
  final String logo;
  final bool hd;
  final bool uhd;
  final String type;
  final String url;
  final String? subtitle;
  final String? epgSource;
  final String? epgId;
  final bool isGeoblocked;
  final bool isDisabled;
  final bool isFeed;
  final bool isRadio;
  final bool isAdult;

  const Channel({
    required this.lcn,
    required this.name,
    required this.logo,
    this.hd = false,
    this.uhd = false,
    required this.type,
    required this.url,
    this.subtitle,
    this.epgSource,
    this.epgId,
    this.isGeoblocked = false,
    this.isDisabled = false,
    this.isFeed = false,
    this.isRadio = false,
    this.isAdult = false,
  });

  /// Whether this channel can be played by media_kit (HLS/DASH without DRM).
  bool get isPlayable =>
      !isDisabled &&
      !isRadio &&
      !isAdult &&
      (type == 'hls' || type == 'dash') &&
      !url.startsWith('zappr://');

  /// Full URL to the channel's logo on Supabase Storage.
  // We force .png extension here because we've uploaded PNGs to fix the black SVG issue.
  // We also sanitise the filename to remove accented characters which cause upload issues on Supabase.
  String get logoUrl {
    final pngLogo = _sanitiseFilename(logo.replaceAll('.svg', '.png'));
    return 'https://enfaqgwmuytoxkxgqqvp.supabase.co/storage/v1/object/public/channel-logos/$pngLogo';
  }

  static String _sanitiseFilename(String filename) {
    return filename
        .toLowerCase()
        .replaceAll('à', 'a')
        .replaceAll('è', 'e')
        .replaceAll('é', 'e')
        .replaceAll('ì', 'i')
        .replaceAll('ò', 'o')
        .replaceAll('ù', 'u');
  }

  factory Channel.fromJson(Map<String, dynamic> json) {
    final epg = json['epg'] as Map<String, dynamic>?;
    final geoblock = json['geoblock'];
    final radio = json['radio'];
    final adult = json['adult'];

    // ── Resolve best stream URL ──
    // Collect all candidate URLs from the JSON in priority order.
    // geoblock.url is preferred because it's a CDN alternative that works
    // without special HTTP headers; main url is next; fallback.url is last.
    final mainUrl = (json['url'] as String?) ?? '';
    final geoblockUrl = (geoblock is Map<String, dynamic>)
        ? (geoblock['url'] as String?) ?? ''
        : '';
    final fallbackUrl = (json['fallback'] is Map<String, dynamic>)
        ? ((json['fallback'] as Map<String, dynamic>)['url'] as String?) ?? ''
        : '';

    // CDN hosts that require HTTP headers mpv/media_kit cannot inject.
    bool isMpvIncompatible(String url) => url.contains('akamaized.net');

    // Priority order: geoblock URL → main URL → fallback URL.
    final candidates = [geoblockUrl, mainUrl, fallbackUrl];
    // First pass: pick the first valid URL that mpv can play.
    String streamUrl = candidates.firstWhere(
      (u) => u.startsWith('http') && !isMpvIncompatible(u),
      orElse: () => '',
    );
    // Second pass: if nothing compatible, accept any valid URL as a last resort.
    if (streamUrl.isEmpty) {
      streamUrl = candidates.firstWhere(
        (u) => u.startsWith('http'),
        orElse: () => '',
      );
    }

    return Channel(
      lcn: json['lcn'] as int,
      name: (json['name'] as String?) ?? '',
      logo: (json['logo'] as String?) ?? '',
      hd: json['hd'] as bool? ?? false,
      uhd: json['uhd'] as bool? ?? false,
      type: (json['type'] as String?) ?? '',
      url: streamUrl,
      subtitle: json['subtitle'] as String?,
      epgSource: epg?['source'] as String?,
      epgId: epg?['id']?.toString(),
      isGeoblocked: geoblock is Map<String, dynamic>,
      isDisabled: json['disabled'] == 'not-working',
      isFeed: json['feed'] as bool? ?? false,
      isRadio: radio == true,
      isAdult: adult == true,
    );
  }
}
