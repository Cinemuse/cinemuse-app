class KitsuMapping {
  final String kitsuId;
  final int? absoluteEpisode;
  final int? anidbId;

  /// The AniList ID of the matched season; AnimeUnity results are matched on
  /// it (REV-232).
  final int? anilistId;

  KitsuMapping({
    required this.kitsuId,
    this.absoluteEpisode,
    this.anidbId,
    this.anilistId,
  });
}
