import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/person.dart';

/// One page of a TMDB list, with TMDB's page count so callers know when to
/// stop loading more.
typedef TmdbPage<T> = ({List<T> results, int totalPages});

/// One result of a list that mixes titles and people (the search, Explore).
sealed class SearchResult {
  const SearchResult();

  /// Reads one result of TMDB's mixed search, where each says its kind.
  factory SearchResult.fromTmdbMap(Map<String, dynamic> map) =>
      map['media_type'] == 'person'
      ? PersonResult(PersonSummary.fromTmdbMap(map))
      : TitleResult(MediaItem.fromTmdbMap(map));

  /// Tells results apart: TMDB's movie, series and person ids overlap.
  String get key;
}

final class TitleResult extends SearchResult {
  final MediaItem title;

  const TitleResult(this.title);

  @override
  String get key => '${title.mediaType.name}:${title.tmdbId}';
}

final class PersonResult extends SearchResult {
  final PersonSummary person;

  const PersonResult(this.person);

  @override
  String get key => 'person:${person.id}';
}
