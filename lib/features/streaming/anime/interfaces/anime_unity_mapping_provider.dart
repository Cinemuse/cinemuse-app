import 'package:cinemuse_app/features/streaming/anime/models/anime_unity_entry.dart';

abstract class AnimeUnityMappingProvider {
  Future<List<AnimeUnityEntry>> getAnimeUnityIds(String kitsuId);
}
