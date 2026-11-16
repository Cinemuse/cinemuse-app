import 'package:cinemuse_app/features/media/domain/media_item.dart';

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

  /// Two-letter language code, e.g. `it`.
  final String language;

  const MediaVideo({
    required this.key,
    required this.name,
    required this.site,
    required this.type,
    required this.language,
  });

  bool get isYouTubeTrailer =>
      site.toLowerCase() == 'youtube' && type.toLowerCase() == 'trailer';

  factory MediaVideo.fromTmdbMap(Map<String, dynamic> map) {
    return MediaVideo(
      key: map['key'] as String? ?? '',
      name: map['name'] as String? ?? '',
      site: map['site'] as String? ?? '',
      type: map['type'] as String? ?? '',
      language: map['iso_639_1'] as String? ?? '',
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
