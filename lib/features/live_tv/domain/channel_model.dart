import 'package:cinemuse_app/features/live_tv/domain/channel_name.dart';
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
  /// favourites and recents: see [ChannelName.rowId].
  String get uniqueId => _ids[this] ??= ChannelName.rowId(name, epgId);

  // Cached per object: the id is read for every channel on each list rebuild.
  static final _ids = Expando<String>();

  /// The link to play: the first one that hasn't failed, else the first.
  StreamLink? get link => links.isEmpty
      ? null
      : links.firstWhere((l) => !l.isFailed, orElse: () => links.first);

  String get url => link?.url ?? '';

  /// The qualities its links have, best first.
  List<StreamQuality> get qualities => StreamQuality.values.reversed
      .where((q) => links.any((l) => l.quality == q))
      .toList();

  /// Combined quality badge
  StreamQuality get quality {
    if (links.isEmpty) return StreamQuality.sd;

    // Pick the highest quality among links
    return links
        .map((l) => l.quality)
        .reduce((a, b) => a.index > b.index ? a : b);
  }
}
