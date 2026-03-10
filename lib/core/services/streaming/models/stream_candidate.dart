import 'package:cinemuse_app/core/services/streaming/models/resolved_stream.dart';

class StreamCandidate {
  final String title;
  final String infoHash;
  final String magnet;
  final int seeds;
  final String provider;
  final int? absoluteEpisode;
  final Map<String, dynamic>? metadata;
  final int score;
  final Map<String, bool> cachedOn; // Provider Name -> Cached Status
  final String? url; // Direct playback URL

  StreamCandidate({
    required this.title,
    required this.infoHash,
    required this.magnet,
    this.seeds = 0,
    required this.provider,
    this.absoluteEpisode,
    this.metadata,
    this.score = 0,
    this.cachedOn = const {},
    this.url,
  });

  bool get isCached => cachedOn.values.any((v) => v);

  /// A robust unique identifier for the stream.
  /// Priority: infoHash > url > fallback (provider:title)
  String get uniqueId {
    if (infoHash.isNotEmpty) return infoHash.toLowerCase();
    if (url != null && url!.isNotEmpty) return url!.toLowerCase();
    // Normalize title for fallback identification
    final normalizedTitle = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return "${provider.toLowerCase()}:$normalizedTitle";
  }

  StreamCandidate copyWith({
    int? score,
    Map<String, bool>? cachedOn,
  }) {
    return StreamCandidate(
      title: title,
      infoHash: infoHash,
      magnet: magnet,
      seeds: seeds,
      provider: provider,
      absoluteEpisode: absoluteEpisode,
      metadata: metadata,
      score: score ?? this.score,
      cachedOn: cachedOn ?? this.cachedOn,
      url: url,
    );
  }
}
