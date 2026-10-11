import 'package:cinemuse_app/features/media/domain/media_item.dart';

class AgendaEvent {
  final String
  id; // Unique ID: movie_{tmdbId} or series_{tmdbId}_s{season}e{episode}
  final int tmdbId;
  final String title;
  final String? episodeName;
  final String? posterPath;
  final String? backdropPath;
  final DateTime releaseDate;
  final bool isTbd;
  final String? customReleaseDate;
  final MediaKind type;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? overview;

  AgendaEvent({
    required this.id,
    required this.tmdbId,
    required this.title,
    this.episodeName,
    this.posterPath,
    this.backdropPath,
    required this.releaseDate,
    this.isTbd = false,
    this.customReleaseDate,
    required this.type,
    this.seasonNumber,
    this.episodeNumber,
    this.overview,
  });

  /// Reads a TMDB date. No date, or text such as "2026" / "TBD", is a TBD
  /// event sorted at the end of its year (or far in the future).
  static ({DateTime date, bool isTbd, String? custom}) _parseReleaseDate(
    String? value,
  ) {
    if (value == null || value.isEmpty) {
      return (date: DateTime(2099, 12, 31), isTbd: true, custom: null);
    }
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return (date: parsed, isTbd: false, custom: null);
    final year = RegExp(r'\d{4}').firstMatch(value)?.group(0);
    return (
      date: DateTime(year != null ? int.parse(year) : 2099, 12, 31),
      isTbd: true,
      custom: value,
    );
  }

  factory AgendaEvent.fromMovie(Map<String, dynamic> json) {
    final release = _parseReleaseDate(
      json['release_date'] ?? json['primary_release_date'],
    );

    return AgendaEvent(
      id: 'movie_${json['id']}',
      tmdbId: json['id'],
      title: json['title'] ?? json['original_title'] ?? '',
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      releaseDate: release.date,
      isTbd: release.isTbd,
      customReleaseDate: release.custom,
      type: MediaKind.movie,
      overview: json['overview'],
    );
  }

  factory AgendaEvent.fromEpisode({
    required int seriesId,
    required String seriesName,
    required String? seriesPosterPath,
    required Map<String, dynamic> epJson,
  }) {
    final release = _parseReleaseDate(epJson['air_date']);

    return AgendaEvent(
      id: 'series_${seriesId}_s${epJson['season_number']}e${epJson['episode_number']}',
      tmdbId: seriesId,
      title: seriesName,
      episodeName: epJson['name'],
      posterPath: seriesPosterPath,
      backdropPath: epJson['still_path'],
      releaseDate: release.date,
      isTbd: release.isTbd,
      customReleaseDate: release.custom,
      type: MediaKind.tv,
      seasonNumber: epJson['season_number'],
      episodeNumber: epJson['episode_number'],
      overview: epJson['overview'],
    );
  }
}
