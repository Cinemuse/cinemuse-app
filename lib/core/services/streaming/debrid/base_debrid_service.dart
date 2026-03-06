abstract class BaseDebridService {
  String get name;
  bool get isEnabled;
  Future<Map<String, bool>> checkAvailability(List<String> hashes);
  Future<Map<String, dynamic>?> resolve(
    String magnet, {
    int? season,
    int? episode,
    int? absoluteEpisode,
    int? fileId,
  });
}
