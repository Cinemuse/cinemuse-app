enum MediaKind {
  movie,
  episode,
  tv,
}

class MediaItem {
  final int tmdbId;
  final MediaKind mediaType;
  final String? titleIt;
  final String? titleEn;
  final String? posterPath;
  final String? backdropPath;
  final int? runtimeMinutes;
  final List<int>? genres;
  final List<int>? castMembers;
  final DateTime? releaseDate;
  final double? voteAverage;
  final DateTime updatedAt;

  MediaItem({
    required this.tmdbId,
    required this.mediaType,
    this.titleIt,
    this.titleEn,
    this.posterPath,
    this.backdropPath,
    this.runtimeMinutes,
    this.genres,
    this.castMembers,
    this.releaseDate,
    this.voteAverage,
    required this.updatedAt,
  });

  /// Returns the localized title based on current language preference,
  /// falling back to English. Returns null if no title is available.
  String? getLocalizedTitle(String languageCode) {
    String? title;
    if (languageCode.toLowerCase() == 'it') {
      title = titleIt;
    }
    title ??= titleEn;
    
    if (title == null || title.trim().isEmpty) return null;
    return title;
  }

  static MediaKind fromString(String type) {
    if (type == 'series' || type == 'tv') return MediaKind.tv;
    if (type == 'episode') return MediaKind.episode;
    return MediaKind.movie;
  }

  static String? _nullIfEmpty(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }

  /// Extracts a localized title from TMDB data (details or search result).
  /// Handles the 'translations' object, primary title/name, and empty strings.
  static String? extractTitleFromTmdb(Map<String, dynamic> data, String languageCode) {
    final translations = data['translations']?['translations'] as List?;
    if (translations != null) {
      for (final t in translations) {
        final translatedData = t['data'] as Map<String, dynamic>;
        // TMDB typically uses iso_639_1 for translations data but 
        // sometimes iso_3166_1 for the keys. We check both to be safe.
        final iso639 = t['iso_639_1']?.toString().toLowerCase();
        final iso3166 = t['iso_3166_1']?.toString().toLowerCase();
        
        if (iso639 == languageCode.toLowerCase() || iso3166 == languageCode.toLowerCase()) {
          final title = _nullIfEmpty(translatedData['title'] ?? translatedData['name']);
          if (title != null) return title;
        }
      }
    }

    // Fallback to primary title/name if translation is missing or language matches English
    return _nullIfEmpty(data['title'] ?? data['name']);
  }

  /// Creates a MediaItem from full TMDB details (Map representation).
  /// This centralizes extraction for all fields (titles, paths, genres, cast, etc.).
  factory MediaItem.fromTmdbDetails(Map<String, dynamic> details, MediaKind type) {
    final titleIt = extractTitleFromTmdb(details, 'it');
    final titleEn = extractTitleFromTmdb(details, 'en');
    
    // Extract cast (top 10)
    final cast = (details['credits']?['cast'] as List?)
        ?.take(10)
        .map((c) => c['id'] as int)
        .toList();

    // Extract genres
    final genres = details['genres'] is List 
        ? (details['genres'] as List).map((e) => e['id'] as int).toList()
        : null;

    // Resolve runtime (handle both formats)
    final runtime = details['runtime'] ?? 
        (details['episode_run_time'] is List && (details['episode_run_time'] as List).isNotEmpty 
            ? details['episode_run_time'][0] 
            : null);

    return MediaItem(
      tmdbId: int.parse(details['id'].toString()),
      mediaType: type,
      titleIt: titleIt,
      titleEn: titleEn,
      posterPath: details['poster_path'],
      backdropPath: details['backdrop_path'],
      runtimeMinutes: runtime,
      genres: genres,
      castMembers: cast,
      releaseDate: DateTime.tryParse(details['release_date'] ?? details['first_air_date'] ?? ''),
      voteAverage: (details['vote_average'] as num?)?.toDouble(),
      updatedAt: DateTime.now(),
    );
  }

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      tmdbId: json['tmdb_id'] as int,
      mediaType: MediaItem.fromString(json['media_type']?.toString() ?? 'movie'),
      titleIt: _nullIfEmpty(json['title_it'] as String?),
      titleEn: _nullIfEmpty(json['title_en'] as String?),
      posterPath: _nullIfEmpty(json['poster_path'] as String?),
      backdropPath: _nullIfEmpty(json['backdrop_path'] as String?),
      runtimeMinutes: json['runtime_minutes'] as int?,
      genres: json['genres'] is List 
          ? (json['genres'] as List<dynamic>).map((e) => e as int).toList()
          : null,
      castMembers: json['cast_members'] is List 
          ? (json['cast_members'] as List<dynamic>).map((e) => e as int).toList()
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
      'title_it': titleIt,
      'title_en': titleEn,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'runtime_minutes': runtimeMinutes,
      'genres': genres,
      'cast_members': castMembers,
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
      'title_it': titleIt,
      'title_en': titleEn,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'runtime_minutes': runtimeMinutes,
      'genres': genres,
      'cast_members': castMembers,
      'release_date': releaseDate?.toIso8601String().split('T').first,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
