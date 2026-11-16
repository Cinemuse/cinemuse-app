/// The anime a TMDB title or episode is, from the anime list.
class AnimeMatch {
  /// The built-in anime source's results are matched on it (REV-232).
  final int anilistId;
  final int? anidbId;

  /// Null for the few anime Kitsu doesn't know: the sources that ask by
  /// Kitsu id then skip them.
  final String? kitsuId;

  /// The anime's own episode; null for a film or a show with no episode
  /// asked.
  final int? absoluteEpisode;

  const AnimeMatch({
    required this.anilistId,
    this.anidbId,
    this.kitsuId,
    this.absoluteEpisode,
  });

  /// The server's `match` (`{"anilist_id": 142853, "kitsu_id": 45607,
  /// "episode": 13}`).
  factory AnimeMatch.fromJson(Map<String, dynamic> json) => AnimeMatch(
    anilistId: json['anilist_id'] as int,
    anidbId: json['anidb_id'] as int?,
    kitsuId: (json['kitsu_id'] as int?)?.toString(),
    absoluteEpisode: json['episode'] as int?,
  );
}

/// Whether a title is anime at all (the list has it, even when no line
/// covers the episode, REV-331) and the anime it is, if any.
class AnimeLookup {
  final bool isAnime;
  final AnimeMatch? match;

  const AnimeLookup({required this.isAnime, this.match});

  static const notAnime = AnimeLookup(isAnime: false);
}
