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
