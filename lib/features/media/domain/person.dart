import 'package:cinemuse_app/features/media/domain/media_item.dart';

/// Strongly-typed domain entity representing a person's credit (cast or crew).
class PersonCredit {
  final int id;
  final MediaKind mediaType;
  final String title;
  final String? posterPath;
  final String? role; // character or job
  final DateTime? releaseDate;
  final double voteAverage;
  final int voteCount;
  final List<int> genreIds;

  const PersonCredit({
    required this.id,
    required this.mediaType,
    required this.title,
    this.posterPath,
    this.role,
    this.releaseDate,
    this.voteAverage = 0.0,
    this.voteCount = 0,
    this.genreIds = const [],
  });

  String get releaseYear {
    if (releaseDate == null) return '';
    return releaseDate!.year.toString();
  }

  factory PersonCredit.fromTmdbMap(Map<String, dynamic> map) {
    final mediaTypeString = map['media_type'] as String?;
    final MediaKind type;
    if (mediaTypeString != null) {
      type = MediaItem.fromString(mediaTypeString);
    } else {
      type = (map['first_air_date'] != null || map['name'] != null)
          ? MediaKind.tv
          : MediaKind.movie;
    }

    final dateStr = (map['release_date'] ?? map['first_air_date'])?.toString();
    final rawGenres = map['genre_ids'] as List?;
    final genreIds = rawGenres != null
        ? rawGenres.whereType<num>().map((e) => e.toInt()).toList()
        : <int>[];

    return PersonCredit(
      id: (map['id'] as num?)?.toInt() ?? 0,
      mediaType: type,
      title: (map['title'] ?? map['name'] ?? '').toString().trim(),
      posterPath: map['poster_path'] as String?,
      role: (map['character'] ?? map['job'] ?? '').toString().trim(),
      releaseDate: dateStr != null ? DateTime.tryParse(dateStr) : null,
      voteAverage: (map['vote_average'] as num?)?.toDouble() ?? 0.0,
      voteCount: (map['vote_count'] as num?)?.toInt() ?? 0,
      genreIds: genreIds,
    );
  }
}

/// Strongly-typed domain entity representing full biographical details of a person.
class PersonDetails {
  final int id;
  final String name;
  final String? profilePath;
  final String? biography;
  final String? birthday;
  final String? placeOfBirth;
  final String? homepage;
  final List<PersonCredit> cast;
  final List<PersonCredit> crew;
  final ExternalIds? externalIds;

  const PersonDetails({
    required this.id,
    required this.name,
    this.profilePath,
    this.biography,
    this.birthday,
    this.placeOfBirth,
    this.homepage,
    this.cast = const [],
    this.crew = const [],
    this.externalIds,
  });

  factory PersonDetails.fromTmdbMap(Map<String, dynamic> map) {
    final rawCast = (map['combined_credits']?['cast'] as List?) ?? [];
    final cast = rawCast
        .whereType<Map>()
        .map((c) => PersonCredit.fromTmdbMap(Map<String, dynamic>.from(c)))
        .toList();

    final rawCrew = (map['combined_credits']?['crew'] as List?) ?? [];
    final crew = rawCrew
        .whereType<Map>()
        .map((c) => PersonCredit.fromTmdbMap(Map<String, dynamic>.from(c)))
        .toList();

    final rawExt = map['external_ids'];
    final externalIds = rawExt is Map
        ? ExternalIds.fromTmdbMap(Map<String, dynamic>.from(rawExt))
        : null;

    return PersonDetails(
      id: (map['id'] as num?)?.toInt() ?? 0,
      name: (map['name'] ?? '').toString().trim(),
      profilePath: map['profile_path'] as String?,
      biography: map['biography'] as String?,
      birthday: map['birthday'] as String?,
      placeOfBirth: map['place_of_birth'] as String?,
      homepage: map['homepage'] as String?,
      cast: cast,
      crew: crew,
      externalIds: externalIds,
    );
  }
}
