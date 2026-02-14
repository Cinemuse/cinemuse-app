enum MediaKind {
  movie,
  episode,
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
    required this.updatedAt,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      tmdbId: json['tmdb_id'] as int,
      mediaType: MediaKind.values.firstWhere(
        (e) => e.name == json['media_type'],
        orElse: () => MediaKind.movie,
      ),
      title: json['title'] as String,
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      runtimeMinutes: json['runtime_minutes'] as int?,
      genres: (json['genres'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      releaseDate: json['release_date'] != null ? DateTime.tryParse(json['release_date'] as String) : null,
      updatedAt: DateTime.parse(json['updated_at'] as String),
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
      'release_date': releaseDate?.toIso8601String().split('T').first, // Date only
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
