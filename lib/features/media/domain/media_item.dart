import 'package:cinemuse_app/features/media/domain/episode_item.dart';

enum MediaKind { movie, episode, tv }

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
  final String? overview;

  // Rich detail fields (populated on details screen)
  final String? tagline;
  final String? status;
  final int? numberOfSeasons;
  final int? numberOfEpisodes;
  final String? homepage;
  final List<MediaGenre>? genreList;
  final List<SeasonSummary>? seasons;
  final List<CastMember>? cast;
  final List<CrewMember>? crew;
  final List<CrewMember>? creators;
  final List<MediaVideo>? videos;
  final MediaImages? images;
  final MediaCollection? collection;
  final ExternalIds? externalIds;

  /// Optional raw TMDB JSON map retained for backwards compatibility
  /// while legacy sub-widgets are incrementally migrated.
  final Map<String, dynamic>? rawTmdbData;

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
    this.overview,
    this.tagline,
    this.status,
    this.numberOfSeasons,
    this.numberOfEpisodes,
    this.homepage,
    this.genreList,
    this.seasons,
    this.cast,
    this.crew,
    this.creators,
    this.videos,
    this.images,
    this.collection,
    this.externalIds,
    this.rawTmdbData,
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

  /// Titles saved by older versions while TMDB details were missing.
  static const _placeholderTitles = {'Unknown', '...'};

  /// Whether the title for [languageCode] is a real one, not missing or a
  /// placeholder (then the details still need to be fetched).
  bool hasCompleteTitle(String languageCode) {
    final title = getLocalizedTitle(languageCode)?.trim();
    return title != null && !_placeholderTitles.contains(title);
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
  static String? extractTitleFromTmdb(
    Map<String, dynamic> data,
    String languageCode,
  ) {
    final translations = data['translations']?['translations'] as List?;
    if (translations != null) {
      for (final t in translations) {
        final translatedData = t['data'] as Map<String, dynamic>;
        // TMDB typically uses iso_639_1 for translations data but
        // sometimes iso_3166_1 for the keys. We check both to be safe.
        final iso639 = t['iso_639_1']?.toString().toLowerCase();
        final iso3166 = t['iso_3166_1']?.toString().toLowerCase();

        if (iso639 == languageCode.toLowerCase() ||
            iso3166 == languageCode.toLowerCase()) {
          final title = _nullIfEmpty(
            translatedData['title'] ?? translatedData['name'],
          );
          if (title != null) return title;
        }
      }
    }

    // Fallback to primary title/name if translation is missing or language matches English
    return _nullIfEmpty(
      data['title'] ??
          data['name'] ??
          data['original_title'] ??
          data['original_name'],
    );
  }

  /// Creates a MediaItem from full TMDB details (Map representation).
  /// This centralizes extraction for all fields (titles, paths, genres, cast, etc.).
  factory MediaItem.fromTmdbDetails(
    Map<String, dynamic> details,
    MediaKind type,
  ) {
    final titleIt = extractTitleFromTmdb(details, 'it');
    final titleEn = extractTitleFromTmdb(details, 'en');

    // Extract cast members
    final rawCast = (details['credits']?['cast'] as List?) ?? [];
    final cast = rawCast.whereType<Map>().map((c) {
      return CastMember.fromTmdbMap(Map<String, dynamic>.from(c));
    }).toList();

    // Legacy cast IDs (top 10)
    final castIds = cast.take(10).map((c) => c.id).toList();

    // Extract crew members
    final rawCrew = (details['credits']?['crew'] as List?) ?? [];
    final crew = rawCrew.whereType<Map>().map((c) {
      return CrewMember.fromTmdbMap(Map<String, dynamic>.from(c));
    }).toList();

    // Extract creators (series created_by)
    final rawCreators = (details['created_by'] as List?) ?? [];
    final creators = rawCreators.whereType<Map>().map((c) {
      return CrewMember.fromTmdbMap(Map<String, dynamic>.from(c));
    }).toList();

    // Extract genres
    final rawGenres = (details['genres'] as List?) ?? [];
    final genreList = rawGenres.whereType<Map>().map((g) {
      return MediaGenre.fromTmdbMap(Map<String, dynamic>.from(g));
    }).toList();
    final genreIds = genreList.map((g) => g.id).toList();

    // Extract videos
    final rawVideos = (details['videos']?['results'] as List?) ?? [];
    final videos = rawVideos.whereType<Map>().map((v) {
      return MediaVideo.fromTmdbMap(Map<String, dynamic>.from(v));
    }).toList();

    // Extract images
    final images = details['images'] is Map
        ? MediaImages.fromTmdbMap(Map<String, dynamic>.from(details['images']))
        : null;

    // Extract seasons
    final rawSeasons = (details['seasons'] as List?) ?? [];
    final seasons = rawSeasons.whereType<Map>().map((s) {
      return SeasonSummary.fromTmdbMap(Map<String, dynamic>.from(s));
    }).toList();

    // Extract collection
    final rawCollection = details['belongs_to_collection'];
    final collection = rawCollection is Map
        ? MediaCollection.fromTmdbMap(Map<String, dynamic>.from(rawCollection))
        : null;

    // Extract external IDs
    final rawExternalIds = details['external_ids'];
    final externalIds = rawExternalIds is Map
        ? ExternalIds.fromTmdbMap(Map<String, dynamic>.from(rawExternalIds))
        : null;

    // Resolve runtime (handle both formats)
    final runtime =
        details['runtime'] ??
        (details['episode_run_time'] is List &&
                (details['episode_run_time'] as List).isNotEmpty
            ? details['episode_run_time'][0]
            : null);

    return MediaItem(
      tmdbId: int.tryParse(details['id']?.toString() ?? '') ?? 0,
      mediaType: type,
      titleIt: titleIt,
      titleEn: titleEn,
      posterPath: details['poster_path'],
      backdropPath: details['backdrop_path'],
      runtimeMinutes: runtime is num ? runtime.toInt() : null,
      genres: genreIds.isNotEmpty ? genreIds : null,
      castMembers: castIds.isNotEmpty ? castIds : null,
      releaseDate: DateTime.tryParse(
        details['release_date'] ?? details['first_air_date'] ?? '',
      ),
      voteAverage: (details['vote_average'] as num?)?.toDouble(),
      updatedAt: DateTime.now(),
      overview: details['overview'] as String?,
      tagline: details['tagline'] as String?,
      status: details['status'] as String?,
      numberOfSeasons: (details['number_of_seasons'] as num?)?.toInt(),
      numberOfEpisodes: (details['number_of_episodes'] as num?)?.toInt(),
      homepage: details['homepage'] as String?,
      genreList: genreList,
      seasons: seasons,
      cast: cast,
      crew: crew,
      creators: creators,
      videos: videos,
      images: images,
      collection: collection,
      externalIds: externalIds,
      rawTmdbData: details,
    );
  }

  factory MediaItem.fromTmdbMap(Map<String, dynamic> map) {
    final mediaTypeString = map['media_type'] as String?;
    final MediaKind type;
    if (mediaTypeString != null) {
      type = MediaItem.fromString(mediaTypeString);
    } else {
      type = (map['first_air_date'] != null || map['name'] != null)
          ? MediaKind.tv
          : MediaKind.movie;
    }

    final titleIt = extractTitleFromTmdb(map, 'it');
    final titleEn = extractTitleFromTmdb(map, 'en');

    return MediaItem(
      tmdbId: int.parse(map['id'].toString()),
      mediaType: type,
      titleIt: titleIt,
      titleEn: titleEn,
      posterPath: map['poster_path'] as String?,
      backdropPath: map['backdrop_path'] as String?,
      releaseDate: DateTime.tryParse(
        (map['release_date'] ?? map['first_air_date'] ?? '').toString(),
      ),
      voteAverage: (map['vote_average'] as num?)?.toDouble(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'].toString())
          : DateTime(2000),
      overview: map['overview'] as String?,
    );
  }

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      tmdbId: json['tmdb_id'] as int,
      mediaType: MediaItem.fromString(
        json['media_type']?.toString() ?? 'movie',
      ),
      titleIt: _nullIfEmpty(json['title_it'] as String?),
      titleEn: _nullIfEmpty(json['title_en'] as String?),
      posterPath: _nullIfEmpty(json['poster_path'] as String?),
      backdropPath: _nullIfEmpty(json['backdrop_path'] as String?),
      runtimeMinutes: json['runtime_minutes'] as int?,
      genres: json['genres'] is List
          ? (json['genres'] as List<dynamic>).map((e) => e as int).toList()
          : null,
      castMembers: json['cast_members'] is List
          ? (json['cast_members'] as List<dynamic>)
                .map((e) => e as int)
                .toList()
          : null,
      releaseDate: json['release_date'] != null
          ? DateTime.tryParse(json['release_date'] as String)
          : null,
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      overview: json['overview'] as String?,
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
      'overview': overview,
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

/// Strongly-typed domain entity representing a TMDB movie collection (franchise).
class MediaCollection {
  final int id;
  final String name;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final List<MediaItem> parts;

  const MediaCollection({
    required this.id,
    required this.name,
    this.overview,
    this.posterPath,
    this.backdropPath,
    required this.parts,
  });

  factory MediaCollection.fromTmdbMap(Map<String, dynamic> json) {
    final rawParts = json['parts'] as List? ?? [];
    final items = rawParts.whereType<Map>().map((part) {
      final map = Map<String, dynamic>.from(part);
      return MediaItem(
        tmdbId: (map['id'] as num?)?.toInt() ?? 0,
        mediaType: MediaKind.movie,
        titleEn: map['title'] as String? ?? map['name'] as String? ?? '',
        posterPath: map['poster_path'] as String?,
        backdropPath: map['backdrop_path'] as String?,
        releaseDate: DateTime.tryParse(map['release_date'] as String? ?? ''),
        voteAverage: (map['vote_average'] as num?)?.toDouble(),
        updatedAt: DateTime.now(),
      );
    }).toList();

    return MediaCollection(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      overview: json['overview'] as String?,
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      parts: items,
    );
  }
}

/// Strongly-typed domain entity for a media genre.
class MediaGenre {
  final int id;
  final String name;

  const MediaGenre({required this.id, required this.name});

  factory MediaGenre.fromTmdbMap(Map<String, dynamic> map) {
    return MediaGenre(
      id: (map['id'] as num?)?.toInt() ?? 0,
      name: map['name'] as String? ?? '',
    );
  }
}

/// Strongly-typed domain entity for a cast member.
class CastMember {
  final int id;
  final String name;
  final String? character;
  final String? profilePath;
  final int? order;

  const CastMember({
    required this.id,
    required this.name,
    this.character,
    this.profilePath,
    this.order,
  });

  factory CastMember.fromTmdbMap(Map<String, dynamic> map) {
    return CastMember(
      id: (map['id'] as num?)?.toInt() ?? 0,
      name: map['name'] as String? ?? '',
      character: map['character'] as String?,
      profilePath: map['profile_path'] as String?,
      order: (map['order'] as num?)?.toInt(),
    );
  }
}

/// Strongly-typed domain entity for a crew member.
class CrewMember {
  final int id;
  final String name;
  final String? job;
  final String? department;
  final String? profilePath;

  const CrewMember({
    required this.id,
    required this.name,
    this.job,
    this.department,
    this.profilePath,
  });

  factory CrewMember.fromTmdbMap(Map<String, dynamic> map) {
    return CrewMember(
      id: (map['id'] as num?)?.toInt() ?? 0,
      name: map['name'] as String? ?? '',
      job: map['job'] as String?,
      department: map['department'] as String?,
      profilePath: map['profile_path'] as String?,
    );
  }
}

/// Strongly-typed domain entity for a media video (trailer, teaser, featurette).
class MediaVideo {
  final String key;
  final String name;
  final String site;
  final String type;

  const MediaVideo({
    required this.key,
    required this.name,
    required this.site,
    required this.type,
  });

  bool get isYouTubeTrailer =>
      site.toLowerCase() == 'youtube' && type.toLowerCase() == 'trailer';

  factory MediaVideo.fromTmdbMap(Map<String, dynamic> map) {
    return MediaVideo(
      key: map['key'] as String? ?? '',
      name: map['name'] as String? ?? '',
      site: map['site'] as String? ?? '',
      type: map['type'] as String? ?? '',
    );
  }
}

/// Strongly-typed domain entity for gallery image paths.
class MediaImages {
  final List<String> backdrops;
  final List<String> posters;
  final List<String> logos;

  const MediaImages({
    this.backdrops = const [],
    this.posters = const [],
    this.logos = const [],
  });

  bool get isEmpty => backdrops.isEmpty && posters.isEmpty && logos.isEmpty;
  bool get isNotEmpty => !isEmpty;

  factory MediaImages.fromTmdbMap(Map<String, dynamic> map) {
    List<String> extractPaths(dynamic list) {
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((item) => item['file_path'] as String?)
          .whereType<String>()
          .toList();
    }

    return MediaImages(
      backdrops: extractPaths(map['backdrops']),
      posters: extractPaths(map['posters']),
      logos: extractPaths(map['logos']),
    );
  }
}

/// Strongly-typed domain entity for external social and database IDs.
class ExternalIds {
  final String? imdbId;
  final String? wikidataId;
  final String? facebookId;
  final String? instagramId;
  final String? twitterId;

  const ExternalIds({
    this.imdbId,
    this.wikidataId,
    this.facebookId,
    this.instagramId,
    this.twitterId,
  });

  bool get hasAnyId =>
      (imdbId != null && imdbId!.trim().isNotEmpty) ||
      (wikidataId != null && wikidataId!.trim().isNotEmpty) ||
      (facebookId != null && facebookId!.trim().isNotEmpty) ||
      (instagramId != null && instagramId!.trim().isNotEmpty) ||
      (twitterId != null && twitterId!.trim().isNotEmpty);

  factory ExternalIds.fromTmdbMap(Map<String, dynamic> map) {
    return ExternalIds(
      imdbId: map['imdb_id'] as String?,
      wikidataId: map['wikidata_id'] as String?,
      facebookId: map['facebook_id'] as String?,
      instagramId: map['instagram_id'] as String?,
      twitterId: map['twitter_id'] as String?,
    );
  }
}
