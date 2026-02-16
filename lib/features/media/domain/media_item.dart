enum MediaKind {
  movie,
  episode,
  tv,
}

class MediaItem {
  final int tmdbId;
  final MediaKind mediaType;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final int? runtimeMinutes;
  final List<String>? genres;
  final DateTime? releaseDate;
  final double? voteAverage;
  final DateTime updatedAt;

  MediaItem({
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    this.posterPath,
    this.backdropPath,
    this.runtimeMinutes,
    this.genres,
    this.releaseDate,
    this.voteAverage,
    required this.updatedAt,
  });

  static MediaKind fromString(String type) {
    if (type == 'series' || type == 'tv') return MediaKind.tv;
    if (type == 'episode') return MediaKind.episode;
    return MediaKind.movie;
  }

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      tmdbId: json['tmdb_id'] as int,
      mediaType: MediaItem.fromString(json['media_type']?.toString() ?? 'movie'),
      title: json['title'] as String? ?? 'Unknown',
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      runtimeMinutes: json['runtime_minutes'] as int?,
      genres: json['genres'] is List 
          ? (json['genres'] as List<dynamic>).map((e) => e.toString()).toList()
          : null,
      releaseDate: json['release_date'] != null ? DateTime.tryParse(json['release_date'] as String) : null,
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tmdb_id': tmdbId,
      'media_type': mediaType.name,
      'title': title,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'runtime_minutes': runtimeMinutes,
      'genres': genres,
      'release_date': releaseDate?.toIso8601String().split('T').first,
      'vote_average': voteAverage,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// JSON for database persistence (matches media_cache schema)
  Map<String, dynamic> toDbJson() {
    return {
      'tmdb_id': tmdbId,
      'media_type': mediaType.name,
      'title': title,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'runtime_minutes': runtimeMinutes,
      'genres': genres,
      'release_date': releaseDate?.toIso8601String().split('T').first,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
