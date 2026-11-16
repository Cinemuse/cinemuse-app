import 'package:cinemuse_app/features/streaming/subtitles/opensubtitles_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic>? paramsFor(int season, int episode) =>
      OpenSubtitlesProvider.buildSearchParams(
        tmdbId: '1429',
        season: season,
        episode: episode,
        language: 'en',
      );

  test('an episode searches the show by its TMDB id', () {
    expect(paramsFor(2, 4), {
      'languages': 'en',
      'order_by': 'download_count',
      'order_direction': 'desc',
      'type': 'episode',
      'parent_tmdb_id': 1429,
      'season_number': 2,
      'episode_number': 4,
    });
  });

  // REV-329: season 0 was taken as "no season", so a special searched for
  // the movie with the show's TMDB id.
  test('a special searches season 0 of the show', () {
    final params = paramsFor(0, 37);

    expect(params?['type'], 'episode');
    expect(params?['parent_tmdb_id'], 1429);
    expect(params?.containsKey('tmdb_id'), isFalse);
    expect(params?['season_number'], 0);
    expect(params?['episode_number'], 37);
  });
}
