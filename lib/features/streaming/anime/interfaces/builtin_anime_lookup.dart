import 'package:cinemuse_app/features/streaming/anime/models/builtin_anime_entry.dart';
import 'package:cinemuse_app/features/streaming/anime/models/anime_match.dart';

abstract class BuiltInAnimeLookup {
  /// The built-in anime site's entries of exactly [mapping]'s anime season, or
  /// null when it has none.
  Future<BuiltInAnimeEntries?> findEntries(AnimeMatch mapping);
}
