import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';

/// A TV channel from the user's playlists.
class Channel {
  final int lcn;
  final String name;
  final String logo;
  final List<StreamLink> links;
  final String? group;
  final String? provider;
  final String? epgId;

  const Channel({
    required this.lcn,
    required this.name,
    required this.logo,
    this.links = const [],
    this.group,
    this.provider,
    this.epgId,
  });

  Channel copyWith({
    int? lcn,
    String? name,
    String? logo,
    List<StreamLink>? links,
    String? group,
    String? provider,
    String? epgId,
  }) {
    return Channel(
      lcn: lcn ?? this.lcn,
      name: name ?? this.name,
      logo: logo ?? this.logo,
      links: links ?? this.links,
      group: group ?? this.group,
      provider: provider ?? this.provider,
      epgId: epgId ?? this.epgId,
    );
  }

  /// Stable id, used to merge channels across playlists and to save
  /// favourites and recents: `epg:<tvg-id>`, or `name:<name without quality
  /// words>`. Never the number: without `tvg-chno` it is the position in the
  /// file, so it changes when the provider adds a channel (REV-113).
  String get uniqueId => _ids[this] ??= _buildId(epgId, name);

  // Cached per object: the id is read for every channel on each list rebuild.
  static final _ids = Expando<String>();
  static final _qualityWords = RegExp(r'\b(fhd|uhd|hd|sd|4k|1080p|720p)\b');
  static final _symbols = RegExp(r'[^\w\s]');
  static final _spaces = RegExp(r'\s+');

  static String _buildId(String? epgId, String name) {
    if (epgId != null && epgId.trim().isNotEmpty) {
      return 'epg:${epgId.trim().toLowerCase()}';
    }
    final normalized = name
        .toLowerCase()
        .replaceAll(_qualityWords, '')
        .replaceAll(_symbols, '')
        .replaceAll(_spaces, ' ')
        .trim();
    return 'name:$normalized';
  }

  /// The link to play: the first one that hasn't failed, else the first.
  String get url {
    if (links.isNotEmpty) {
      // Return first non-failed link, or just the first link
      return links
          .firstWhere((l) => !l.isFailed, orElse: () => links.first)
          .url;
    }
    return '';
  }

  /// Combined quality badge
  StreamQuality get quality {
    if (links.isEmpty) return StreamQuality.sd;

    // Pick the highest quality among links
    return links
        .map((l) => l.quality)
        .reduce((a, b) => a.index > b.index ? a : b);
  }
}
