import 'dart:io' show Platform;
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';

/// Model representing a TV channel from zappr.stream.
class Channel {
  final int lcn;
  final String name;
  final String logo;
  final bool hd;
  final bool uhd;
  final String? type;
  final String? urlOverride; // Keep for static/stable URLs
  final List<StreamLink> links;
  final String? group;
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
    this.type,
    this.urlOverride,
    this.links = const [],
    this.group,
    this.subtitle,
    this.epgSource,
    this.epgId,
    this.isGeoblocked = false,
    this.isDisabled = false,
    this.isFeed = false,
    this.isRadio = false,
    this.isAdult = false,
  });

  /// Unique identifier for this channel.
  /// Since many IPTV channels lack a unique LCN, we use a combination of name and LCN.
  String get uniqueId => '${name}_$lcn'.hashCode.toString();

  /// Whether this channel can be played by media_kit (HLS/DASH without DRM).
  ///
  /// On Windows, DASH streams are excluded because libmpv's DASH demuxer
  /// corrupts process-global state — after opening a .mpd stream, subsequent
  /// open() calls crash with an access violation (0xc0000005).
  bool get isPlayable =>
      !isDisabled &&
      !isRadio &&
      !isAdult &&
      (type == 'hls' || 
       (type == 'dash' && !Platform.isWindows) || 
       links.isNotEmpty) &&
      !(urlOverride?.startsWith('zappr://') ?? false);

  /// Backward compatibility: returns the primary URL (Override or first link)
  String get url {
    if (urlOverride != null && urlOverride!.isNotEmpty) return urlOverride!;
    if (links.isNotEmpty) {
      // Return first non-failed link, or just the first link
      return links.firstWhere((l) => !l.isFailed, orElse: () => links.first).url;
    }
    return '';
  }

  /// Combined quality badge
  StreamQuality get quality {
    if (uhd) return StreamQuality.uhd;
    if (hd) return StreamQuality.hd;
    if (links.isEmpty) return StreamQuality.sd;
    
    // Pick the highest quality among links
    return links.map((l) => l.quality).reduce((a, b) => a.index > b.index ? a : b);
  }

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

    // --- Dynamic links handling ---
    List<StreamLink> streamLinks = [];
    if (json['links'] != null) {
      streamLinks = (json['links'] as List)
          .map((l) => StreamLink.fromJson(l as Map<String, dynamic>))
          .toList();
    }

    // --- Legacy Best Stream Resolution (Keep for stability) ---
    final mainUrl = (json['url'] as String?) ?? '';
    final geoblockUrl = (geoblock is Map<String, dynamic>)
        ? (geoblock['url'] as String?) ?? ''
        : '';
    final fallbackUrl = (json['fallback'] is Map<String, dynamic>)
        ? ((json['fallback'] as Map<String, dynamic>)['url'] as String?) ?? ''
        : '';

    bool isMpvIncompatible(String url) => url.contains('akamaized.net');
    final candidates = [geoblockUrl, mainUrl, fallbackUrl];
    
    String resolvedUrl = candidates.firstWhere(
      (u) => u.startsWith('http') && !isMpvIncompatible(u),
      orElse: () => '',
    );
    if (resolvedUrl.isEmpty) {
      resolvedUrl = candidates.firstWhere(
        (u) => u.startsWith('http'),
        orElse: () => '',
      );
    }

    return Channel(
      lcn: json['lcn'] as int? ?? 0,
      name: (json['name'] as String?) ?? '',
      logo: (json['logo'] as String?) ?? '',
      hd: json['hd'] as bool? ?? false,
      uhd: json['uhd'] as bool? ?? false,
      type: json['type'] as String?,
      urlOverride: resolvedUrl.isNotEmpty ? resolvedUrl : null,
      links: streamLinks,
      group: json['group'] as String?,
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
