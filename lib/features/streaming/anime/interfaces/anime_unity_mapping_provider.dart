import 'package:cinemuse_app/features/streaming/anime/models/anime_unity_entry.dart';
import 'package:cinemuse_app/features/streaming/anime/models/kitsu_mapping.dart';

abstract class AnimeUnityMappingProvider {
  /// The AnimeUnity entries of exactly [mapping]'s anime season, or `[]`.
  Future<List<AnimeUnityEntry>> getAnimeUnityIds(KitsuMapping mapping);
}
