import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// The made-up film's TMDB id.
const filmId = 101;

/// The made-up series' TMDB id.
const seriesId = 202;

/// The made-up actor's TMDB id.
const personId = 303;

/// Long on purpose: every screen must fit the longest names it can get.
const filmTitle =
    'Il favoloso viaggio di Amélie attraverso le stagioni della vita';
const seriesTitle = 'Le cronache straordinarie della famiglia Montecristo';
const personName = 'Maria Alessandra Bianchi-Fontanarossa';
const episodeTitle = 'Il ritorno inatteso del conte e la lettera mai spedita';

const _overview =
    'Una giovane donna lascia la sua città per inseguire un sogno che '
    'nessuno capisce: tra incontri inattesi, amori lontani e segreti di '
    'famiglia scopre che il viaggio più difficile è quello verso casa. '
    'Una storia di coraggio, amicizia e seconde possibilità.';

/// Answers the app's TMDB requests with made-up titles in TMDB's own shape,
/// so the app reads them as it reads TMDB's. Any other address is not found.
class MadeUpTmdbAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final uri = options.uri;
    final answer = uri.host == 'api.themoviedb.org'
        ? _answer(uri.path.replaceFirst('/3', ''))
        : null;
    if (answer == null) return ResponseBody.fromString('', 404);
    return ResponseBody.fromString(
      jsonEncode(answer),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic>? _answer(String path) {
  final parts = path.split('/').where((p) => p.isNotEmpty).toList();
  return switch (parts) {
    ['trending', ...] => _page(_mixed()),
    ['movie', 'now_playing'] || ['discover', 'movie'] => _page(_films()),
    ['discover', 'tv'] => _page(_series()),
    ['search', 'multi'] => _page([..._mixed(), _personSummary(personId)]),
    ['person', 'popular'] => _page([
      for (var i = 0; i < 12; i++) _personSummary(personId + i),
    ]),
    ['person', final id] => _person(int.parse(id)),
    ['movie', final id] => _filmDetails(int.parse(id)),
    ['tv', final id] => _seriesDetails(int.parse(id)),
    ['tv', _, 'season', final season] => _season(int.parse(season)),
    ['collection', _] => {
      'id': 404,
      'name': 'La saga completa del favoloso viaggio di Amélie',
      'overview': _overview,
      'parts': [for (var i = 0; i < 4; i++) _film(filmId + i)],
    },
    ['watch', 'providers', 'regions'] => {
      'results': [
        {'iso_3166_1': 'IT', 'english_name': 'Italy', 'native_name': 'Italia'},
        {
          'iso_3166_1': 'GB',
          'english_name': 'United Kingdom',
          'native_name': 'Regno Unito',
        },
      ],
    },
    ['watch', 'providers', _] => {
      'results': [
        for (final (i, name) in [
          'Netflix',
          'Amazon Prime Video',
          'Disney Plus',
          'Apple TV Plus',
          'NOW',
          'Paramount Plus',
        ].indexed)
          {
            'provider_id': i + 1,
            'provider_name': name,
            'logo_path': '/logo$i.jpg',
            'display_priorities': {'IT': i},
          },
      ],
    },
    _ => null,
  };
}

Map<String, dynamic> _page(List<Map<String, dynamic>> results) => {
  'page': 1,
  'results': results,
  'total_pages': 1,
  'total_results': results.length,
};

List<Map<String, dynamic>> _films() => [
  for (var i = 0; i < 12; i++) _film(filmId + i),
];

List<Map<String, dynamic>> _series() => [
  for (var i = 0; i < 12; i++) _show(seriesId + i),
];

List<Map<String, dynamic>> _mixed() => [
  for (var i = 0; i < 6; i++) ...[_film(filmId + i), _show(seriesId + i)],
];

Map<String, dynamic> _film(int id) => {
  'id': id,
  'media_type': 'movie',
  'title': filmTitle,
  'original_title': filmTitle,
  'overview': _overview,
  'poster_path': '/poster$id.jpg',
  'backdrop_path': '/backdrop$id.jpg',
  'release_date': '2024-03-15',
  'vote_average': 7.8,
  'vote_count': 12345,
  'genre_ids': [18, 35, 10749],
};

Map<String, dynamic> _show(int id) => {
  'id': id,
  'media_type': 'tv',
  'name': seriesTitle,
  'original_name': seriesTitle,
  'overview': _overview,
  'poster_path': '/poster$id.jpg',
  'backdrop_path': '/backdrop$id.jpg',
  'first_air_date': '2022-09-30',
  'vote_average': 8.4,
  'vote_count': 6789,
  'genre_ids': [18, 9648],
};

Map<String, dynamic> _personSummary(int id) => {
  'id': id,
  'media_type': 'person',
  'name': personName,
  'profile_path': '/person$id.jpg',
  'known_for_department': 'Acting',
};

List<Map<String, dynamic>> _cast() => [
  for (var i = 0; i < 10; i++)
    {
      'id': personId + i,
      'name': personName,
      'character': 'Contessa Elisabetta di Montecristo (da giovane)',
      'profile_path': '/person$i.jpg',
      'order': i,
    },
];

List<Map<String, dynamic>> _crew() => [
  {
    'id': personId + 50,
    'name': 'Giovanni Battista Rossellini-Moretti',
    'job': 'Director',
    'department': 'Directing',
  },
  {
    'id': personId + 51,
    'name': 'Francesca Lucrezia Vanzina',
    'job': 'Screenplay',
    'department': 'Writing',
  },
];

Map<String, dynamic> _details(Map<String, dynamic> base) => {
  ...base,
  'tagline': 'Ogni viaggio comincia con un passo, e il suo con mille.',
  'status': 'Released',
  'genres': [
    {'id': 18, 'name': 'Dramma'},
    {'id': 35, 'name': 'Commedia'},
    {'id': 10749, 'name': 'Romantico'},
    {'id': 9648, 'name': 'Mistero'},
  ],
  'credits': {'cast': _cast(), 'crew': _crew()},
  'videos': {
    'results': [
      for (var i = 0; i < 4; i++)
        {
          'key': 'video$i',
          'name':
              'Trailer ufficiale italiano numero ${i + 1} (versione estesa)',
          'site': 'YouTube',
          'type': 'Trailer',
          'iso_639_1': 'it',
        },
    ],
  },
  'images': {
    'backdrops': [
      for (var i = 0; i < 6; i++) {'file_path': '/still$i.jpg'},
    ],
    'posters': [
      for (var i = 0; i < 4; i++) {'file_path': '/poster$i.jpg'},
    ],
    'logos': <Map<String, dynamic>>[],
  },
  'recommendations': {'results': _mixed()},
  'similar': {'results': _mixed()},
  'external_ids': {'imdb_id': 'tt0000101'},
  'reviews': {'results': <Map<String, dynamic>>[]},
  'translations': {'translations': <Map<String, dynamic>>[]},
};

Map<String, dynamic> _filmDetails(int id) => _details({
  ..._film(id),
  'runtime': 142,
  'belongs_to_collection': {
    'id': 404,
    'name': 'La saga completa del favoloso viaggio di Amélie',
    'poster_path': '/collection.jpg',
    'backdrop_path': '/collection-backdrop.jpg',
  },
});

Map<String, dynamic> _seriesDetails(int id) => _details({
  ..._show(id),
  'number_of_seasons': 3,
  'number_of_episodes': 30,
  'episode_run_time': [52],
  'created_by': [
    {'id': personId + 60, 'name': 'Giovanni Battista Rossellini-Moretti'},
  ],
  'last_episode_to_air': {'season_number': 3, 'episode_number': 10},
  'seasons': [
    for (var s = 1; s <= 3; s++)
      {
        'id': 9000 + s,
        'season_number': s,
        'name': 'Stagione $s',
        'episode_count': 10,
        'air_date': '202${1 + s}-09-30',
        'poster_path': '/season$s.jpg',
      },
  ],
});

Map<String, dynamic> _season(int season) => {
  'season_number': season,
  'name': 'Stagione $season',
  'episodes': [
    for (var e = 1; e <= 10; e++)
      {
        'id': season * 100 + e,
        'season_number': season,
        'episode_number': e,
        'name': episodeTitle,
        'overview': _overview,
        'air_date': '2023-10-${(e + 1).toString().padLeft(2, '0')}',
        'runtime': 52,
        'still_path': '/still$e.jpg',
        'vote_average': 8.1,
      },
  ],
};

Map<String, dynamic> _person(int id) => {
  ..._personSummary(id),
  'biography': '$_overview $_overview',
  'birthday': '1978-05-21',
  'place_of_birth': 'San Giovanni in Fiore, Calabria, Italia',
  'combined_credits': {
    'cast': [
      for (final t in _mixed())
        {...t, 'character': 'Contessa Elisabetta di Montecristo'},
    ],
    'crew': [
      {..._film(filmId), 'job': 'Producer', 'department': 'Production'},
    ],
  },
  'external_ids': {'imdb_id': 'nm0000303', 'instagram_id': 'maria.bianchi'},
  'images': {
    'profiles': [
      for (var i = 0; i < 3; i++) {'file_path': '/profile$i.jpg'},
    ],
  },
};
