import 'package:cinemuse_app/core/services/anime/kitsu_mapping_service.dart';

class MediaContext {
  final String tmdbId;
  final String type; // 'movie' or 'tv'
  final String? imdbId;
  final int? season;
  final int? episode;
  final KitsuMapping? kitsuMapping;
  final bool isAnime;

  MediaContext({
    required this.tmdbId,
    required this.type,
    this.imdbId,
    this.season,
    this.episode,
    this.kitsuMapping,
    this.isAnime = false,
  });

  String? get strmiomdbId {
    if (imdbId == null) return null;
    if (type == 'tv' && season != null && episode != null) {
      return "$imdbId:$season:$episode";
    }
    return imdbId;
  }
}
