class BuiltInAnimeEntry {
  /// The anime's number on the built-in anime site (e.g. 12 from `/anime/12-one-piece`).
  final int id;

  /// The full path from the mapping (e.g. `/anime/12-one-piece`).
  final String path;

  BuiltInAnimeEntry({required this.id, required this.path});
}

/// An anime season's entries on the built-in anime site, found on one visit.
class BuiltInAnimeEntries {
  /// The site's address on this visit, followed if the site moved: the
  /// episodes and the video must come from the same place as the search.
  final String siteAddress;

  /// Never empty.
  final List<BuiltInAnimeEntry> entries;

  BuiltInAnimeEntries({required this.siteAddress, required this.entries});
}
