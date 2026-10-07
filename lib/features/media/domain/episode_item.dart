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
}

class SeasonSummary {
  final int seasonNumber;
  final String? name;
  final int? episodeCount;

  const SeasonSummary({
    required this.seasonNumber,
    this.name,
    this.episodeCount,
  });

  factory SeasonSummary.fromTmdbMap(Map<String, dynamic> map) {
    return SeasonSummary(
      seasonNumber: (map['season_number'] as num?)?.toInt() ?? 0,
      name: map['name'] as String?,
      episodeCount: (map['episode_count'] as num?)?.toInt(),
    );
  }
}
