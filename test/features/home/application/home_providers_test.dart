import 'dart:async';
import 'dart:math';

import 'package:cinemuse_app/core/data/server_addresses_model.dart';
import 'package:cinemuse_app/features/media/application/own_reviews_provider.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/media/domain/own_review.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:dio/dio.dart';
import 'package:cinemuse_app/core/data/server_addresses_repository.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/home/application/home_providers.dart';
import 'package:cinemuse_app/features/home/domain/sport_tv_event.dart';
import 'package:cinemuse_app/features/media/application/watch_history_store.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

/// Answers each `load()` with the next result: a list, or a failure.
class _FakeSitesRepository implements ServerAddressesRepository {
  final List<Object> results;

  _FakeSitesRepository(this.results);

  @override
  Future<ServerAddresses> load() async {
    final next = results.removeAt(0);
    if (next is AppFailure) throw next;
    return next as ServerAddresses;
  }

  @override
  Future<ServerAddresses> fetchFromServer() => load();
}

SportTvEvent _event(String name, DateTime? at) => SportTvEvent(
  dateTime: at,
  sportName: name,
  description: '',
  channels: const [],
);

void main() {
  group('sportScheduleProvider site list (STR-08)', () {
    ProviderContainer container(List<Object> results) {
      final c = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          serverAddressesRepositoryProvider.overrideWithValue(
            _FakeSitesRepository(results),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('no sport address in the list: an empty schedule', () async {
      final c = container([ServerAddresses.empty]);

      expect(await c.read(sportScheduleProvider.future), isEmpty);
    });

    test('the Home row does not keep a failed list for the scrapers', () async {
      final c = container([
        const NetworkFailure('offline'),
        ServerAddresses({
          ServerAddress.movieSite.key: 'https://movies.example',
        }),
      ]);
      // Home stays on screen, so its row keeps listening.
      c.listen(sportScheduleProvider, (_, _) {});
      await expectLater(
        c.read(sportScheduleProvider.future),
        throwsA(isA<NetworkFailure>()),
      );
      await Future<void>.delayed(Duration.zero);

      final sites = await c.read(serverAddressesProvider.future);
      expect(sites.baseUrl(ServerAddress.movieSite), 'https://movies.example');
    });
  });

  group('upcomingSportEvents', () {
    final now = DateTime(2026, 10, 11, 20);

    test('drops events that started more than 3 hours ago', () {
      final result = upcomingSportEvents([
        _event('yesterday', DateTime(2026, 10, 10, 21)),
        _event('long ago today', DateTime(2026, 10, 11, 16, 59)),
        _event('still on', DateTime(2026, 10, 11, 18)),
        _event('later', DateTime(2026, 10, 11, 22)),
      ], now);

      expect(result.map((e) => e.sportName), ['still on', 'later']);
    });

    test('sorts by start time and keeps events without a time last', () {
      final result = upcomingSportEvents([
        _event('no time', null),
        _event('late', DateTime(2026, 10, 12, 9)),
        _event('early', DateTime(2026, 10, 11, 21)),
      ], now);

      expect(result.map((e) => e.sportName), ['early', 'late', 'no time']);
    });
  });

  group('Home rows leave out what was finished or dropped', () {
    MediaItem title(int id, MediaKind kind) =>
        MediaItem(tmdbId: id, mediaType: kind, updatedAt: DateTime.utc(2026));

    WatchHistory history(int id, MediaKind kind, WatchStatus? status) =>
        WatchHistory(
          userId: 'user-a',
          tmdbId: id,
          mediaType: kind,
          status: status,
          lastWatchedAt: DateTime.utc(2026),
        );

    final row = FutureProvider<List<MediaItem>>(
      (ref) async => [
        title(1, MediaKind.movie),
        title(1, MediaKind.tv),
        title(2, MediaKind.tv),
        title(3, MediaKind.movie),
        title(4, MediaKind.tv),
      ],
    );

    test('finished and dropped go, watching and untouched stay', () async {
      final c = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          shownWatchHistoryProvider.overrideWithValue(
            AsyncData({
              for (final h in [
                history(1, MediaKind.movie, WatchStatus.completed),
                history(2, MediaKind.tv, WatchStatus.dropped),
                history(3, MediaKind.movie, WatchStatus.watching),
                history(4, MediaKind.tv, null),
              ])
                h.titleKey: h,
            }),
          ),
        ],
      );
      addTearDown(c.dispose);
      c.listen(unseenHomeTitlesProvider(row), (_, _) {});
      await c.read(row.future);

      final shown = c.read(unseenHomeTitlesProvider(row)).value!;

      // The series sharing the finished film's id stays.
      expect(shown.map((t) => '${t.mediaType.name}-${t.tmdbId}'), [
        'tv-1',
        'movie-3',
        'tv-4',
      ]);
    });
  });

  group('the "like X" rows', () {
    MediaItem title(int id, MediaKind kind) => MediaItem(
      tmdbId: id,
      mediaType: kind,
      titleEn: 'Title $id',
      updatedAt: DateTime.utc(2026),
    );

    final film1 = title(1, MediaKind.movie);
    final series2 = title(2, MediaKind.tv);
    final film3 = title(3, MediaKind.movie);
    final series4 = title(4, MediaKind.tv);
    final film5 = title(5, MediaKind.movie);

    UserList favourites(List<MediaItem> titles) => UserList(
      id: 'fav',
      userId: 'user-a',
      name: 'Favorites',
      type: ListType.favorites,
      createdAt: DateTime.utc(2026),
      items: [
        for (final t in titles)
          UserListItem(
            listId: 'fav',
            mediaType: t.mediaType,
            tmdbId: t.tmdbId,
            addedAt: DateTime.utc(2026),
            media: t,
          ),
      ],
    );

    OwnReview rated(MediaItem t, int rating) => OwnReview(
      tmdbId: t.tmdbId,
      mediaType: t.mediaType,
      rating: rating,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    WatchHistory watched(MediaItem t) => WatchHistory(
      userId: 'user-a',
      tmdbId: t.tmdbId,
      mediaType: t.mediaType,
      status: WatchStatus.completed,
      lastWatchedAt: DateTime.utc(2026),
      media: t,
    );

    late StreamController<List<UserList>> lists;
    late _FakeRandom random;
    late _SuggestionsTmdbService tmdb;

    setUp(() {
      lists = StreamController<List<UserList>>.broadcast();
      random = _FakeRandom();
      tmdb = _SuggestionsTmdbService();
    });
    tearDown(() => lists.close());

    Future<ProviderContainer> container({
      required List<MediaItem> favouriteTitles,
      List<(MediaItem, int)> ratings = const [],
    }) async {
      final c = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          userListsProvider.overrideWith(
            () => _FakeUserListsNotifier(lists.stream),
          ),
          allOwnReviewsProvider.overrideWith(
            (ref) async => {
              for (final (t, value) in ratings)
                rated(t, value).titleKey: rated(t, value),
            },
          ),
          shownWatchHistoryProvider.overrideWithValue(
            AsyncData({
              for (final (t, _) in ratings) watched(t).titleKey: watched(t),
            }),
          ),
          lovedPickRandomProvider.overrideWithValue(random),
          tmdbServiceProvider.overrideWithValue(tmdb),
        ],
      );
      addTearDown(c.dispose);
      c.listen(lovedPicksProvider, (_, _) {});
      await c.read(allOwnReviewsProvider.future);
      lists.add([favourites(favouriteTitles)]);
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    String key(MediaItem? t) => '${t?.mediaType.name}-${t?.tmdbId}';

    test(
      'Favourites and titles rated 8 or more are loved, each once',
      () async {
        final c = await container(
          favouriteTitles: [film1, series2],
          ratings: [(film1, 9), (film3, 8), (series4, 7)],
        );

        expect(
          c.read(lovedTitlesProvider).map(key),
          unorderedEquals(['movie-1', 'tv-2', 'movie-3']),
        );
      },
    );

    test('one loved film and one loved series are picked', () async {
      random.next = [1, 0];

      final c = await container(favouriteTitles: [film1, series2, film3]);

      final picks = c.read(lovedPicksProvider);
      expect(key(picks.film), 'movie-3');
      expect(key(picks.series), 'tv-2');
    });

    test('a pick stays while the lists change; pull to refresh picks '
        'another', () async {
      final c = await container(favouriteTitles: [film1, series2]);
      expect(key(c.read(lovedPicksProvider).film), 'movie-1');

      lists.add([
        favourites([film1, series2, film3, film5]),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(key(c.read(lovedPicksProvider).film), 'movie-1');

      c.read(lovedPicksProvider.notifier).pickAgain();
      expect(key(c.read(lovedPicksProvider).film), isNot('movie-1'));
      expect(key(c.read(lovedPicksProvider).series), 'tv-2');
    });

    test('a pick taken out of Favourites is replaced', () async {
      final c = await container(favouriteTitles: [film1, series2]);

      lists.add([
        favourites([series2, film3]),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(key(c.read(lovedPicksProvider).film), 'movie-3');
    });

    test('the film row asks TMDB for the picked film; with no loved series '
        'the series row is empty and asks nothing', () async {
      final c = await container(favouriteTitles: [film3]);

      final films = await c.read(
        lovedSuggestionsProvider(MediaKind.movie).future,
      );
      final series = await c.read(
        lovedSuggestionsProvider(MediaKind.tv).future,
      );

      expect(tmdb.asked, [(MediaKind.movie, 3)]);
      expect(films.map((t) => t.tmdbId), [30]);
      expect(series, isEmpty);
    });
  });
}

class _FakeUserListsNotifier extends UserListsNotifier {
  _FakeUserListsNotifier(this._lists);
  final Stream<List<UserList>> _lists;

  @override
  Stream<List<UserList>> build() => _lists;
}

/// Gives the numbers in [next], then 0.
class _FakeRandom implements Random {
  List<int> next = [];

  @override
  int nextInt(int max) => next.isEmpty ? 0 : next.removeAt(0) % max;

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();
}

/// Suggests one title, its id × 10, and remembers what was asked.
class _SuggestionsTmdbService extends TmdbService {
  _SuggestionsTmdbService() : super(Dio(), 'en-US', () async => 'test-key');

  final asked = <(MediaKind, int)>[];

  @override
  Future<List<MediaItem>> getSuggestions(MediaKind type, int tmdbId) async {
    asked.add((type, tmdbId));
    return [
      MediaItem(
        tmdbId: tmdbId * 10,
        mediaType: type,
        updatedAt: DateTime.utc(2026),
      ),
    ];
  }
}
