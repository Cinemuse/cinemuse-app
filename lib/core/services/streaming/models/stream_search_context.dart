import 'package:cinemuse_app/core/services/anime/kitsu_mapping_service.dart';

/// Context object containing all necessary information to search for media streams
/// across various providers (Stremio, AnimeTosho, etc.).
class StreamSearchContext {
  /// The primary TMDB identifier for the content.
  final String tmdbId;
  
  /// The type of media: 'movie' or 'tv'.
  final String type;
  
  /// The primary title of the content (Movie title or Show title).
  final String title;
  
  /// The Standard Industry identifier (tt1234567).
  final String? imdbId;
  
  /// For series, the season number (1-indexed).
  final int? season;
  
  /// For series, the episode number (1-indexed).
  final int? episode;
  
  /// The name of the specific episode being searched (if available).
  final String? episodeName;
  
  /// The name of the season (if available).
  final String? seasonName;
  
  /// External mapping data (e.g. Kitsu) used for non-western ID resolution.
  final KitsuMapping? mapping;
  
  /// Whether this search is specifically for an Anime title.
  final bool isAnime;

  StreamSearchContext({
    required this.tmdbId,
    required this.type,
    required this.title,
    this.imdbId,
    this.season,
    this.episode,
    this.episodeName,
    this.seasonName,
    this.mapping,
    this.isAnime = false,
  });

  /// Returns a Stremio-compatible ID format.
  /// Movie: tt1234567
  /// Series: tt1234567:1:5
  String? get strmiomdbId {
    if (imdbId == null) return null;
    if (type == 'tv' && season != null && episode != null) {
      return "$imdbId:$season:$episode";
    }
    return imdbId;
  }
}
