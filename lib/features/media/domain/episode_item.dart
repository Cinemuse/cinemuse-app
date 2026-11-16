class EpisodeItem {
  final int episodeNumber;
  final int seasonNumber;
  final String? name;
  final String? overview;
  final String? stillPath;
  final int? runtime;
  final DateTime? airDate;

  const EpisodeItem({
    required this.episodeNumber,
    required this.seasonNumber,
    this.name,
    this.overview,
    this.stillPath,
    this.runtime,
    this.airDate,
  });

  /// Resolves the display title, falling back to [fallback] if [name] is null or empty.
  String getTitle(String fallback) {
    if (name != null && name!.trim().isNotEmpty) {
      return name!;
    }
    return fallback;
  }

  factory EpisodeItem.fromTmdbMap(
    Map<String, dynamic> map, {
    int seasonNumber = 1,
  }) {
    final airDateStr = map['air_date']?.toString();
    final epNum = (map['episode_number'] as num?)?.toInt() ?? 1;
    final sNum = (map['season_number'] as num?)?.toInt() ?? seasonNumber;
    return EpisodeItem(
      episodeNumber: epNum,
      seasonNumber: sNum,
      name: map['name'] as String?,
      overview: map['overview'] as String?,
      stillPath: map['still_path'] as String?,
      runtime: (map['runtime'] as num?)?.toInt(),
      airDate: airDateStr != null ? DateTime.tryParse(airDateStr) : null,
    );
  }

  /// The episodes of TMDB's season answer, in TMDB's order.
  static List<EpisodeItem> listFromTmdbSeason(
    Map<String, dynamic> season,
    int seasonNumber,
  ) => (season['episodes'] as List? ?? const [])
      .whereType<Map>()
      .map(
        (e) => EpisodeItem.fromTmdbMap(
          Map<String, dynamic>.from(e),
          seasonNumber: seasonNumber,
        ),
      )
      .toList();
}

class SeasonSummary {
  final int seasonNumber;
  final String? name;
  final int? episodeCount;

  /// When the season's first episode aired (or will air).
  final DateTime? airDate;

  const SeasonSummary({
    required this.seasonNumber,
    this.name,
    this.episodeCount,
    this.airDate,
  });

  factory SeasonSummary.fromTmdbMap(Map<String, dynamic> map) {
    return SeasonSummary(
      seasonNumber: (map['season_number'] as num?)?.toInt() ?? 0,
      name: map['name'] as String?,
      episodeCount: (map['episode_count'] as num?)?.toInt(),
      airDate: DateTime.tryParse('${map['air_date'] ?? ''}'),
    );
  }

  /// A show's seasons as the season picker lists them: the regular seasons
  /// in order, then the specials (season 0, extras) at the end (REV-264).
  static List<SeasonSummary> inPickerOrder(List<SeasonSummary> seasons) => [
    ...seasons.where((s) => s.seasonNumber > 0),
    ...seasons.where((s) => s.seasonNumber == 0),
  ];
}
