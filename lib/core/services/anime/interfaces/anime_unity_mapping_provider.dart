import 'package:cinemuse_app/core/services/anime/models/anime_unity_entry.dart';

abstract class AnimeUnityMappingProvider {
  Future<List<AnimeUnityEntry>> getAnimeUnityIds(String kitsuId);
}
