import 'dart:typed_data';

import 'package:cinemuse_app/core/data/api_keys_repository.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/search_result.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with [statusCode] and [body], or fails like an
/// offline device when [offline] is set. Remembers every request.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({this.statusCode = 200, this.body = '{}', this.offline = false});

  final int statusCode;
  final String body;
  final bool offline;
  final requests = <RequestOptions>[];
  RequestOptions? get lastRequest => requests.lastOrNull;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Failed host lookup',
      );
    }
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

TmdbService _service(_FakeAdapter adapter, {TmdbKeyLoader? apiKey}) =>
    TmdbService(
      Dio()..httpClientAdapter = adapter,
      'en-US',
      apiKey ?? () async => 'secret-key',
    );

void main() {
  setUp(AppLogger.clearRecent);

  group('lists throw instead of looking empty (REV-30)', () {
    test('search while offline throws a NetworkFailure', () async {
      final service = _service(_FakeAdapter(offline: true));

      await expectLater(
        service.searchMulti('inception'),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('discover with TMDB down throws a ServerFailure', () async {
      final service = _service(_FakeAdapter(statusCode: 503));

      await expectLater(
        service.discover(type: 'movie', page: 2),
        throwsA(
          isA<ServerFailure>().having((f) => f.statusCode, 'status', 503),
        ),
      );
    });

    test('popular persons while offline throws', () async {
      final service = _service(_FakeAdapter(offline: true));

      await expectLater(
        service.getPopularPersons(1),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('watch providers while offline throws', () async {
      final service = _service(_FakeAdapter(offline: true));

      await expectLater(
        service.getWatchProviders('movie', 'IT'),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('watch providers for series ask for the TV list', () async {
      final adapter = _FakeAdapter(body: '{"results": []}');

      await _service(adapter).getWatchProviders('tv', 'IT');

      expect(adapter.lastRequest!.path, endsWith('/watch/providers/tv'));
    });

    test('the failure message never contains the API key', () async {
      final service = _service(_FakeAdapter(statusCode: 500));

      final failure = await service
          .searchMulti('inception')
          .then<AppFailure?>(
            (_) => null,
            onError: (Object e) => e as AppFailure,
          );

      expect(failure!.message, isNot(contains('secret-key')));
    });
  });

  test('search still sends the key and the query', () async {
    final adapter = _FakeAdapter(
      body: '{"results": [{"id": 1, "media_type": "movie"}], "total_pages": 3}',
    );

    final page = await _service(adapter).searchMulti('inception');

    expect(page.totalPages, 3);
    expect(page.results.single.key, 'movie:1');
    expect(adapter.lastRequest!.queryParameters['api_key'], 'secret-key');
    expect(adapter.lastRequest!.queryParameters['query'], 'inception');
  });

  test('search comes back as titles and people', () async {
    final adapter = _FakeAdapter(
      body:
          '{"results": ['
          '{"id": 27205, "media_type": "movie", "title": "Inception", '
          '"release_date": "2010-07-15", "vote_average": 8.4},'
          '{"id": 1396, "media_type": "tv", "name": "Breaking Bad"},'
          '{"id": 6193, "media_type": "person", "name": "Leonardo DiCaprio", '
          '"profile_path": "/leo.jpg", "known_for_department": "Acting"}'
          ']}',
    );

    final page = await _service(adapter).searchMulti('inception');

    final [film, series, person] = page.results;
    final title = (film as TitleResult).title;
    expect(title.titleEn, 'Inception');
    expect(title.releaseDate, DateTime(2010, 7, 15));
    expect(title.voteAverage, 8.4);
    expect((series as TitleResult).title.mediaType, MediaKind.tv);
    final who = (person as PersonResult).person;
    expect(who.id, 6193);
    expect(who.name, 'Leonardo DiCaprio');
    expect(who.profilePath, '/leo.jpg');
    expect(who.knownForDepartment, 'Acting');
  });

  test('discover\'s titles are the kind asked for', () async {
    final adapter = _FakeAdapter(
      body:
          '{"results": [{"id": 1399, "name": "Game of Thrones"}], '
          '"total_pages": 7}',
    );

    final page = await _service(adapter).discover(type: 'tv', page: 2);

    expect(page.totalPages, 7);
    expect(page.results.single.tmdbId, 1399);
    expect(page.results.single.mediaType, MediaKind.tv);
    expect(adapter.lastRequest!.path, endsWith('/discover/tv'));
  });

  test('popular people come back as people', () async {
    final adapter = _FakeAdapter(
      body:
          '{"results": [{"id": 287, "name": "Brad Pitt", '
          '"profile_path": "/brad.jpg"}], "total_pages": 500}',
    );

    final page = await _service(adapter).getPopularPersons(1);

    expect(page.totalPages, 500);
    expect(page.results.single.name, 'Brad Pitt');
    expect(page.results.single.profilePath, '/brad.jpg');
  });

  test('a streaming service has its rank in the country asked for, or its '
      'global one', () async {
    final adapter = _FakeAdapter(
      body:
          '{"results": ['
          '{"provider_id": 8, "provider_name": "Netflix", '
          '"logo_path": "/netflix.jpg", "display_priority": 4, '
          '"display_priorities": {"IT": 1, "US": 3}},'
          '{"provider_id": 39, "provider_name": "NOW", "display_priority": 9}'
          ']}',
    );

    final [netflix, now] = await _service(
      adapter,
    ).getWatchProviders('movie', 'IT');

    expect(
      (netflix.id, netflix.name, netflix.logoPath, netflix.priority),
      (8, 'Netflix', '/netflix.jpg', 1),
    );
    expect(now.priority, 9);
  });

  test('countries come back with their name; one with no code is left '
      'out', () async {
    final adapter = _FakeAdapter(
      body:
          '{"results": ['
          '{"iso_3166_1": "IT", "english_name": "Italy", '
          '"native_name": "Italia"},'
          '{"iso_3166_1": "US", "english_name": "United States"},'
          '{"english_name": "Nowhere"}'
          ']}',
    );

    final regions = await _service(adapter).getWatchRegions();

    expect(regions, [
      (code: 'IT', name: 'Italia'),
      (code: 'US', name: 'United States'),
    ]);
  });

  test('with no key, search throws the key failure and asks nothing', () async {
    final adapter = _FakeAdapter();
    final service = _service(
      adapter,
      apiKey: () => Future.error(const NetworkFailure('no key')),
    );

    await expectLater(
      service.searchMulti('inception'),
      throwsA(isA<NetworkFailure>()),
    );
    expect(adapter.lastRequest, isNull);
  });

  test('details ask for the videos in Italian and in English', () async {
    final adapter = _FakeAdapter();

    await _service(adapter).getMediaDetails('27205', 'movie');

    final query = adapter.lastRequest!.queryParameters;
    expect(query['append_to_response'], contains('videos'));
    expect(query['include_video_language'], 'it,en');
  });

  test('details come back as the title, read from TMDB\'s answer', () async {
    final adapter = _FakeAdapter(
      body:
          '{"id": 1396, "name": "Breaking Bad", '
          '"last_episode_to_air": {"season_number": 5, "episode_number": 16}}',
    );
    final service = _service(adapter);

    final show = await service.getMediaDetails('1396', 'series');

    expect(show!.tmdbId, 1396);
    expect(show.mediaType, MediaKind.tv);
    expect(show.tmdbTitle, 'Breaking Bad');
    expect(show.lastAiredEpisode, (season: 5, episode: 16));
    // The second ask is answered from memory: the same title, no request.
    adapter.requests.clear();
    expect(await service.getMediaDetails('1396', 'series'), same(show));
    expect(adapter.lastRequest, isNull);
  });

  test(
    'a season comes back as its episodes, read from TMDB\'s answer',
    () async {
      final service = _service(
        _FakeAdapter(
          body:
              '{"season_number": 2, "episodes": ['
              '{"episode_number": 1, "name": "Pilot", "air_date": "2009-03-08"},'
              '{"episode_number": 2, "name": "Grilled"}]}',
        ),
      );

      final episodes = await service.getSeasonEpisodes(1396, 2);

      expect(episodes!.map((e) => (e.seasonNumber, e.episodeNumber, e.name)), [
        (2, 1, 'Pilot'),
        (2, 2, 'Grilled'),
      ]);
      expect(episodes.first.airDate, DateTime(2009, 3, 8));
    },
  );

  test('a collection comes back with its films', () async {
    final service = _service(
      _FakeAdapter(
        body:
            '{"id": 10, "name": "Star Wars Collection", '
            '"parts": [{"id": 11, "title": "A New Hope"}]}',
      ),
    );

    final collection = await service.getCollectionDetails(10);

    expect(collection!.name, 'Star Wars Collection');
    expect(collection.parts.single.tmdbId, 11);
    expect(collection.parts.single.titleEn, 'A New Hope');
  });

  test('a person comes back with their films and series', () async {
    final service = _service(
      _FakeAdapter(
        body:
            '{"id": 17419, "name": "Bryan Cranston", '
            '"combined_credits": {"cast": [{"id": 1396, "media_type": "tv", '
            '"name": "Breaking Bad", "character": "Walter White"}], '
            '"crew": []}}',
      ),
    );

    final person = await service.getPersonDetails(17419);

    expect(person!.name, 'Bryan Cranston');
    expect(person.cast.single.id, 1396);
  });

  test('only a series\' details ask for its first episode', () async {
    final adapter = _FakeAdapter();
    final service = _service(adapter);

    await service.getMediaDetails('1396', 'tv');
    expect(
      adapter.lastRequest!.queryParameters['append_to_response'],
      contains(MediaItem.firstEpisodeResponse),
    );

    await service.getMediaDetails('27205', 'movie');
    expect(
      adapter.lastRequest!.queryParameters['append_to_response'],
      isNot(contains(MediaItem.firstEpisodeResponse)),
    );
  });

  group('single lookups still return null, but log why', () {
    test(
      'details while offline: null and a log line without the key',
      () async {
        final service = _service(_FakeAdapter(offline: true));

        expect(await service.getMediaDetails('27205', 'movie'), isNull);

        final logged = AppLogger.recent.map((e) => e.message).join('\n');
        expect(logged, contains('/movie/27205'));
        expect(logged, isNot(contains('secret-key')));
      },
    );

    test('a 404 is a real "not found": null and no warning', () async {
      final service = _service(_FakeAdapter(statusCode: 404));

      expect(await service.getPersonDetails(42), isNull);
      expect(AppLogger.recent, isEmpty);
    });
  });

  group('Home rows', () {
    final now = DateTime(2026, 11, 17, 21);
    const twoTitles =
        '{"results": [{"id": 1, "title": "One"}, {"id": 2, "title": "Two"}]}';

    test('each asks for two pages and keeps each title once', () async {
      // The fake answers both pages alike: the second repeats the first.
      final adapter = _FakeAdapter(body: twoTitles);

      final titles = await _service(adapter).getNewSeries(now);

      expect(adapter.requests.map((r) => r.queryParameters['page']), [1, 2]);
      expect(titles.map((t) => t.tmdbId), [1, 2]);
      expect(titles.map((t) => t.mediaType), everyElement(MediaKind.tv));
    });

    test('trending leaves out people and keeps each title once', () async {
      final adapter = _FakeAdapter(
        body:
            '{"results": [{"id": 1, "media_type": "movie"}, '
            '{"id": 1, "media_type": "tv"}, {"id": 5, "media_type": "person"}]}',
      );

      final titles = await _service(adapter).getTrending();

      expect(titles.map((t) => (t.tmdbId, t.mediaType)), [
        (1, MediaKind.movie),
        (1, MediaKind.tv),
      ]);
    });

    test(
      'movies in theaters: the cinemas of the country asked for, re-releases kept',
      () async {
        final adapter = _FakeAdapter(body: twoTitles);

        final titles = await _service(adapter).getMoviesInTheaters('IT');

        expect(adapter.lastRequest!.path, endsWith('/movie/now_playing'));
        final query = adapter.lastRequest!.queryParameters;
        expect(query['region'], 'IT');
        expect(query.keys.where((k) => k.contains('date')), isEmpty);
        expect(titles.first.mediaType, MediaKind.movie);
      },
    );

    test('new movies on streaming: digital releases of the last 45 days, '
        '20 votes or more', () async {
      final adapter = _FakeAdapter(body: twoTitles);

      await _service(adapter).getNewMoviesOnStreaming('IT', now);

      expect(adapter.lastRequest!.path, endsWith('/discover/movie'));
      expect(
        adapter.lastRequest!.queryParameters,
        containsPair('region', 'IT'),
      );
      expect(
        adapter.lastRequest!.queryParameters,
        allOf(
          containsPair('with_release_type', 4),
          containsPair('release_date.gte', '2026-10-03'),
          containsPair('release_date.lte', '2026-11-17'),
          containsPair('vote_count.gte', 20),
        ),
      );
    });

    test(
      'new series: the last 12 months, talk shows and the like left out',
      () async {
        final adapter = _FakeAdapter(body: twoTitles);

        await _service(adapter).getNewSeries(now);

        expect(adapter.lastRequest!.path, endsWith('/discover/tv'));
        expect(
          adapter.lastRequest!.queryParameters,
          allOf(
            containsPair('first_air_date.gte', '2025-11-17'),
            containsPair('first_air_date.lte', '2026-11-17'),
            containsPair('without_genres', '10767|10763|10764|10766|10762'),
          ),
        );
      },
    );

    test('top-rated recent series: the last 3 years, 8 or more from 300 '
        'votes', () async {
      final adapter = _FakeAdapter(body: twoTitles);

      await _service(adapter).getTopRatedRecentSeries(now);

      expect(adapter.lastRequest!.path, endsWith('/discover/tv'));
      expect(
        adapter.lastRequest!.queryParameters,
        allOf(
          containsPair('first_air_date.gte', '2023-11-18'),
          containsPair('vote_average.gte', 8),
          containsPair('vote_count.gte', 300),
          containsPair('without_genres', '10767|10763|10764|10766|10762'),
        ),
      );
    });

    test('a failed page fails the row instead of showing it half', () async {
      final service = _service(_FakeAdapter(offline: true));

      await expectLater(
        service.getMoviesInTheaters('IT'),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}
