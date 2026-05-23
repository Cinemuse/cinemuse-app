class AnimeUnityEntry {
  /// The numeric AnimeUnity anime ID (e.g. 12 from `/anime/12-one-piece`).
  final int id;

  /// The full path from the mapping (e.g. `/anime/12-one-piece`).
  final String path;

  AnimeUnityEntry({required this.id, required this.path});
}
