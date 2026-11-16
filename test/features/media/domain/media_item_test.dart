import 'package:cinemuse_app/features/media/domain/episode_item.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/person.dart';
import 'package:flutter_test/flutter_test.dart';

MediaItem _item({String? en, String? it}) => MediaItem(
  tmdbId: 1,
  mediaType: MediaKind.movie,
  titleEn: en,
  titleIt: it,
  updatedAt: DateTime(2026),
);

void main() {
  group('MediaItem.hasCompleteTitle', () {
    test('a real title is complete', () {
      expect(_item(en: 'Dune').hasCompleteTitle('en'), isTrue);
    });

    test('missing, blank and placeholder titles are not', () {
      expect(_item().hasCompleteTitle('en'), isFalse);
      expect(_item(en: '  ').hasCompleteTitle('en'), isFalse);
      expect(_item(en: 'Unknown').hasCompleteTitle('en'), isFalse);
      expect(_item(en: '...').hasCompleteTitle('en'), isFalse);
    });

    test('checks the title of the given language', () {
      final item = _item(en: 'The Book', it: '...');
      expect(item.hasCompleteTitle('en'), isTrue);
      expect(item.hasCompleteTitle('it'), isFalse);
    });
  });

  group('titles when TMDB leaves the original language blank', () {
    Map<String, dynamic> translation(String language, String title) => {
      'iso_639_1': language,
      'iso_3166_1': language.toUpperCase(),
      'data': {'title': title},
    };

    test('an English original keeps its English title', () {
      final item = MediaItem.fromTmdbDetails({
        'id': 5915,
        'title': 'Into the Wild - Nelle terre selvagge',
        'original_title': 'Into the Wild',
        'original_language': 'en',
        'translations': {
          'translations': [
            translation('en', ''),
            translation('it', 'Into the Wild - Nelle terre selvagge'),
          ],
        },
      }, MediaKind.movie);

      expect(item.titleEn, 'Into the Wild');
      expect(item.titleIt, 'Into the Wild - Nelle terre selvagge');
    });

    test('an Italian original keeps its Italian title', () {
      final item = MediaItem.fromTmdbDetails({
        'id': 1,
        'title': 'The Great Beauty',
        'original_title': 'La grande bellezza',
        'original_language': 'it',
        'translations': {
          'translations': [
            translation('en', 'The Great Beauty'),
            translation('it', ''),
          ],
        },
      }, MediaKind.movie);

      expect(item.titleIt, 'La grande bellezza');
      expect(item.titleEn, 'The Great Beauty');
    });

    test('another language still falls back to the title TMDB sent', () {
      final item = MediaItem.fromTmdbDetails({
        'id': 1,
        'title': 'Il ragazzo e l\'airone',
        'original_title': '君たちはどう生きるか',
        'original_language': 'ja',
      }, MediaKind.movie);

      expect(item.titleEn, 'Il ragazzo e l\'airone');
    });
  });

  group('a series\' episode length', () {
    MediaItem series(Map<String, dynamic> extra) =>
        MediaItem.fromTmdbDetails({'id': 1396, ...extra}, MediaKind.tv);

    test('the show\'s own length wins', () {
      final item = series({
        'episode_run_time': [43],
        MediaItem.firstEpisodeResponse: {'runtime': 59},
      });
      expect(item.runtimeMinutes, 43);
    });

    test('with none, the first episode\'s length is used', () {
      final item = series({
        'episode_run_time': <int>[],
        MediaItem.firstEpisodeResponse: {'runtime': 59},
      });
      expect(item.runtimeMinutes, 59);
    });

    test('with neither, it stays empty', () {
      expect(series({'episode_run_time': <int>[]}).runtimeMinutes, isNull);
      expect(
        series({
          'episode_run_time': <int>[],
          MediaItem.firstEpisodeResponse: {'runtime': 0},
        }).runtimeMinutes,
        isNull,
      );
    });

    test('a film keeps its own runtime', () {
      final item = MediaItem.fromTmdbDetails({
        'id': 5915,
        'runtime': 148,
      }, MediaKind.movie);
      expect(item.runtimeMinutes, 148);
    });
  });

  // The title page, the player and the stream search read these from the
  // title, not from TMDB's raw answer.
  group('what the app reads from TMDB\'s details', () {
    final show = MediaItem.fromTmdbDetails({
      'id': 1396,
      'name': 'Breaking Bad',
      'status': 'Ended',
      'external_ids': {'imdb_id': 'tt0903747'},
      'last_episode_to_air': {'season_number': 5, 'episode_number': 16},
      'seasons': [
        {'season_number': 0, 'episode_count': 9, 'air_date': '2009-02-17'},
        {'season_number': 1, 'episode_count': 7, 'air_date': '2008-01-20'},
        {'season_number': 2, 'episode_count': 13, 'air_date': null},
      ],
      'recommendations': {
        'results': [
          {'id': 1399, 'media_type': 'tv', 'name': 'Game of Thrones'},
          {'id': 27205, 'media_type': 'movie', 'title': 'Inception'},
        ],
      },
    }, MediaKind.tv);

    test('a series: its title, last aired episode and IMDb number', () {
      expect(show.tmdbTitle, 'Breaking Bad');
      expect(show.lastAiredEpisode, (season: 5, episode: 16));
      expect(show.imdbId, 'tt0903747');
      expect(show.status, 'Ended');
    });

    test('its seasons keep TMDB\'s order and their air dates', () {
      expect(
        [
          for (final s in show.seasons!)
            (s.seasonNumber, s.episodeCount, s.airDate),
        ],
        [
          (0, 9, DateTime(2009, 2, 17)),
          (1, 7, DateTime(2008, 1, 20)),
          (2, 13, null),
        ],
      );
    });

    test('the season picker puts the specials last', () {
      expect(
        SeasonSummary.inPickerOrder(show.seasons!).map((s) => s.seasonNumber),
        [1, 2, 0],
      );
    });

    test('"More like this" holds TMDB\'s recommendations', () {
      expect(
        [
          for (final r in show.recommendations!)
            (r.tmdbId, r.mediaType, r.titleEn),
        ],
        [
          (1399, MediaKind.tv, 'Game of Thrones'),
          (27205, MediaKind.movie, 'Inception'),
        ],
      );
    });

    test('a film: its title, and its IMDb number outside external_ids', () {
      final film = MediaItem.fromTmdbDetails({
        'id': 27205,
        'title': 'Inception',
        'imdb_id': 'tt1375666',
      }, MediaKind.movie);

      expect(film.tmdbTitle, 'Inception');
      expect(film.imdbId, 'tt1375666');
      expect(film.lastAiredEpisode, isNull);
      expect(film.recommendations, isEmpty);
    });
  });

  group('MediaItem.kindFromTmdbMap', () {
    final cases = <(String, Map<String, dynamic>, MediaKind)>[
      ('media_type wins', {'media_type': 'tv', 'title': 'X'}, MediaKind.tv),
      (
        'a movie result',
        {'title': 'Dune', 'release_date': '2021'},
        MediaKind.movie,
      ),
      ('a series result by name', {'name': 'Dark'}, MediaKind.tv),
      ('a series result by date', {'first_air_date': '2017'}, MediaKind.tv),
    ];
    for (final (name, map, kind) in cases) {
      test(name, () {
        expect(MediaItem.kindFromTmdbMap(map), kind);
        expect(MediaItem.fromTmdbMap({'id': 1, ...map}).mediaType, kind);
        expect(PersonCredit.fromTmdbMap(map).mediaType, kind);
      });
    }
  });
}
