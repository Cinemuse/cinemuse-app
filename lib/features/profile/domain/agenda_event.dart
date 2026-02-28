import 'package:cinemuse_app/features/media/domain/media_item.dart';

class AgendaEvent {
  final String id; // Unique ID: movie_{tmdbId} or series_{tmdbId}_s{season}e{episode}
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

  factory AgendaEvent.fromMovie(Map<String, dynamic> json) {
    final releaseDateStr = json['release_date'] ?? json['primary_release_date'];
    
    DateTime parsedDate;
    bool isTbd = false;
    String? customDate;

    if (releaseDateStr == null || releaseDateStr.isEmpty) {
      isTbd = true;
      parsedDate = DateTime(2099, 12, 31); // Far future for sorting
    } else {
      try {
        parsedDate = DateTime.parse(releaseDateStr);
      } catch (_) {
        // Handle cases like "2026" or "TBD"
        isTbd = true;
        customDate = releaseDateStr;
        // Try to extract year if possible for sorting
        final yearMatch = RegExp(r'\d{4}').firstMatch(releaseDateStr);
        if (yearMatch != null) {
          parsedDate = DateTime(int.parse(yearMatch.group(0)!), 12, 31);
        } else {
          parsedDate = DateTime(2099, 12, 31);
        }
      }
    }

    return AgendaEvent(
      id: 'movie_${json['id']}',
      tmdbId: json['id'],
      title: json['title'] ?? json['original_title'] ?? '',
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      releaseDate: parsedDate,
      isTbd: isTbd,
      customReleaseDate: customDate,
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
    final airDateStr = epJson['air_date'];
    DateTime parsedDate;
    bool isTbd = false;
    String? customDate;

    if (airDateStr == null || airDateStr.isEmpty) {
      isTbd = true;
      parsedDate = DateTime(2099, 12, 31);
    } else {
      try {
        parsedDate = DateTime.parse(airDateStr);
      } catch (_) {
        isTbd = true;
        customDate = airDateStr;
        final yearMatch = RegExp(r'\d{4}').firstMatch(airDateStr);
        if (yearMatch != null) {
          parsedDate = DateTime(int.parse(yearMatch.group(0)!), 12, 31);
        } else {
          parsedDate = DateTime(2099, 12, 31);
        }
      }
    }

    return AgendaEvent(
      id: 'series_${seriesId}_s${epJson['season_number']}e${epJson['episode_number']}',
      tmdbId: seriesId,
      title: seriesName,
      episodeName: epJson['name'],
      posterPath: seriesPosterPath,
      backdropPath: epJson['still_path'],
      releaseDate: parsedDate,
      isTbd: isTbd,
      customReleaseDate: customDate,
      type: MediaKind.tv,
      seasonNumber: epJson['season_number'],
      episodeNumber: epJson['episode_number'],
      overview: epJson['overview'],
    );
  }
}
