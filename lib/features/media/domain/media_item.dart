import 'package:cinemuse_app/features/media/domain/episode_item.dart';
import 'package:cinemuse_app/features/media/domain/media_details_parts.dart';

enum MediaKind { movie, episode, tv }

class MediaItem {
  /// Where a series' details carry its first episode. Many series have no
  /// length of their own on TMDB, so that episode's length stands in for it.
  static const firstEpisodeResponse = 'season/1/episode/1';

  final int tmdbId;
  final MediaKind mediaType;
  final String? titleIt;
  final String? titleEn;
  final String? posterPath;
  final String? backdropPath;
  final int? runtimeMinutes;
  final List<int>? genres;
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

  /// The title as TMDB sent it, in the language the app asked for (TMDB's
  /// own choice when it has no translation): the one the stream search, the
  /// tracking sheets and their messages use.
  final String? tmdbTitle;

  /// TMDB's IMDb number (a film also carries it outside `external_ids`).
  /// TMDB sends a missing one as null or as an empty string.
  final String? imdbId;

  /// A series' latest aired episode; null when TMDB doesn't say.
  final ({int season, int episode})? lastAiredEpisode;

  /// The "More like this" row.
  final List<MediaItem>? recommendations;

  MediaItem({
    required this.tmdbId,
    required this.mediaType,
    this.titleIt,
    this.titleEn,
    this.posterPath,
    this.backdropPath,
    this.runtimeMinutes,
    this.genres,
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
    this.tmdbTitle,
    this.imdbId,
    this.lastAiredEpisode,
    this.recommendations,
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

  /// The kind of a TMDB list result. Lists of one kind (e.g. a movie search)
  /// send no `media_type`: only series have `name` / `first_air_date`.
  static MediaKind kindFromTmdbMap(Map<String, dynamic> map) {
    final mediaTypeString = map['media_type'] as String?;
    if (mediaTypeString != null) return fromString(mediaTypeString);
    return (map['first_air_date'] != null || map['name'] != null)
        ? MediaKind.tv
        : MediaKind.movie;
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

    // TMDB often leaves a title's own language blank, and its main title is in
    // the language asked for, not this one: the original is the right title.
    if (data['original_language'] == languageCode.toLowerCase()) {
      final original = _nullIfEmpty(
        data['original_title'] ?? data['original_name'],
      );
      if (original != null) return original;
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

    // A film's runtime, a series' own length, or its first episode's. A length
    // of 0 means TMDB doesn't know it.
    final firstEpisodeRuntime = details[firstEpisodeResponse]?['runtime'];
    final runtime =
        details['runtime'] ??
        (details['episode_run_time'] is List &&
                (details['episode_run_time'] as List).isNotEmpty
            ? details['episode_run_time'][0]
            : (firstEpisodeRuntime is num && firstEpisodeRuntime > 0
                  ? firstEpisodeRuntime
                  : null));

    final lastAired = details['last_episode_to_air'];
    final rawRecommendations =
        (details['recommendations']?['results'] as List?) ?? [];

    return MediaItem(
      tmdbId: int.tryParse(details['id']?.toString() ?? '') ?? 0,
      mediaType: type,
      titleIt: titleIt,
      titleEn: titleEn,
      posterPath: details['poster_path'],
      backdropPath: details['backdrop_path'],
      runtimeMinutes: runtime is num ? runtime.toInt() : null,
      genres: genreIds.isNotEmpty ? genreIds : null,
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
      tmdbTitle: (details['title'] ?? details['name']) as String?,
      imdbId: (externalIds?.imdbId ?? details['imdb_id']) as String?,
      lastAiredEpisode: lastAired is Map
          ? (
              season: lastAired['season_number'] as int? ?? 0,
              episode: lastAired['episode_number'] as int? ?? 0,
            )
          : null,
      recommendations: rawRecommendations
          .whereType<Map>()
          .map((r) => MediaItem.fromTmdbMap(Map<String, dynamic>.from(r)))
          .toList(),
    );
  }

  factory MediaItem.fromTmdbMap(Map<String, dynamic> map) {
    final type = kindFromTmdbMap(map);

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
}
