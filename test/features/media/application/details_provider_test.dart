import 'dart:async';

import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/application/watch_history_store.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockWatchHistoryRepository extends Mock
    implements WatchHistoryRepository {}

void main() {
  const movieId = 27205;
  const showId = 1396;

  late StreamController<List<Map<String, dynamic>>> logs;
  late StreamController<List<Map<String, dynamic>>> showLogs;
  late bool isLogStreamCancelled;
  late ProviderContainer container;
  late _MockWatchHistoryRepository repository;

  setUp(() {
    isLogStreamCancelled = false;
    logs = StreamController<List<Map<String, dynamic>>>.broadcast(
      onCancel: () => isLogStreamCancelled = true,
    );
    addTearDown(logs.close);
    showLogs = StreamController<List<Map<String, dynamic>>>.broadcast();
    addTearDown(showLogs.close);

    final auth = _MockGoTrueClient();
    when(() => auth.currentSession).thenReturn(
      Session(
        accessToken: 'token',
        tokenType: 'bearer',
        user: User(
          id: 'user-a',
          appMetadata: {},
          userMetadata: {},
          aud: '',
          createdAt: '',
        ),
      ),
    );
    when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
    final client = _MockSupabaseClient();
    when(() => client.auth).thenReturn(auth);

    repository = _MockWatchHistoryRepository();
    when(
      () => repository.watchTitleLogs('user-a', movieId, 'movie'),
    ).thenAnswer((_) => logs.stream);
    when(
      () => repository.watchTitleLogs('user-a', showId, 'tv'),
    ).thenAnswer((_) => showLogs.stream);

    container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => AuthService(client)),
        watchHistoryRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> pumpEvents() async {
    await container.pump();
    await Future<void>.delayed(Duration.zero);
  }

  const movieLog = {
    'tmdb_id': movieId,
    'media_type': 'movie',
    'logged_at': '2026-10-12T20:00:00Z',
  };

  // REV-191: the log providers were never disposed, so every title opened
  // kept a Supabase realtime channel open for the whole session. REV-287:
  // they stay 5 minutes, so reopening the page shows the count at once.
  test('the movie log stream closes 5 minutes after nothing watches it', () {
    fakeAsync((async) {
      final subscription = container.listen(
        movieWatchCountProvider(movieId),
        (_, __) {},
      );
      logs.add([movieLog]);
      async.flushMicrotasks();
      expect(container.read(movieWatchCountProvider(movieId)), 1);

      subscription.close();
      async.elapse(const Duration(minutes: 4));
      expect(isLogStreamCancelled, isFalse);

      async.elapse(const Duration(minutes: 2));
      expect(isLogStreamCancelled, isTrue);
    });
  });

  // REV-287: while loading, the count read as 0 and Track said "Track"
  // for a watched title.
  test('the counts are unknown while loading, known when reopened', () {
    fakeAsync((async) {
      final status = seriesWatchStatusProvider((
        tmdbId: showId,
        totalEpisodes: 1,
      ));
      final movie = container.listen(
        movieWatchCountProvider(movieId),
        (_, __) {},
      );
      final show = container.listen(status, (_, __) {});
      async.flushMicrotasks();
      expect(container.read(movieWatchCountProvider(movieId)), isNull);
      expect(container.read(status), isNull);

      logs.add([movieLog]);
      showLogs.add([
        {
          'tmdb_id': showId,
          'media_type': 'tv',
          'season': 1,
          'episode': 1,
          'logged_at': '2026-10-12T20:00:00Z',
        },
      ]);
      async.flushMicrotasks();
      movie.close();
      show.close();
      async.elapse(const Duration(minutes: 1));

      container.listen(movieWatchCountProvider(movieId), (_, __) {});
      container.listen(status, (_, __) {});
      expect(container.read(movieWatchCountProvider(movieId)), 1);
      expect(container.read(status)!.isFullyWatched, isTrue);
    });
  });

  // REV-192: "Remove one" on a rewatched episode hid every log of it, and
  // the hide was never dropped while the server still had one.
  test(
    'removing one of two watches shows one, also after the server',
    () async {
      Map<String, dynamic> log(String at) => {
        'tmdb_id': showId,
        'media_type': 'tv',
        'season': 1,
        'episode': 3,
        'logged_at': at,
      };
      container.listen(watchedEpisodesMapProvider(showId), (_, __) {});
      showLogs.add([log('2026-10-01T20:00:00Z'), log('2026-10-12T20:00:00Z')]);
      await pumpEvents();
      expect(container.read(watchedEpisodesMapProvider(showId))['1-3'], 2);

      container
          .read(seriesWatchLogsProvider(showId).notifier)
          .changeEpisodeCount(1, 3, (shown) => shown - 1);
      expect(container.read(watchedEpisodesMapProvider(showId))['1-3'], 1);

      showLogs.add([log('2026-10-01T20:00:00Z')]);
      await pumpEvents();
      expect(container.read(watchedEpisodesMapProvider(showId))['1-3'], 1);

      // Confirmed, so a new watch from elsewhere shows up again.
      showLogs.add([log('2026-10-01T20:00:00Z'), log('2026-10-13T20:00:00Z')]);
      await pumpEvents();
      expect(container.read(watchedEpisodesMapProvider(showId))['1-3'], 2);
    },
  );

  // REV-198: watched specials counted against a total without specials.
  test('watched specials don\'t make a show fully watched', () async {
    Map<String, dynamic> log(int season, int episode) => {
      'tmdb_id': showId,
      'media_type': 'tv',
      'season': season,
      'episode': episode,
      'logged_at': '2026-10-12T20:00:00Z',
    };
    final status = seriesWatchStatusProvider((
      tmdbId: showId,
      totalEpisodes: 2,
    ));
    container.listen(status, (_, __) {});
    showLogs.add([log(0, 1), log(0, 2), log(1, 1)]);
    await pumpEvents();

    expect(container.read(status)!.isFullyWatched, false);
    expect(container.read(status)!.isPartiallyWatched, true);
  });

  // REV-196: a failed save dropped the pending changes of every episode of
  // the show, also the ones still saving.
  test('a failed episode save keeps the other pending episodes', () async {
    container.listen(watchedEpisodesMapProvider(showId), (_, __) {});
    showLogs.add([]);
    await pumpEvents();

    container.read(seriesWatchLogsProvider(showId).notifier)
      ..changeEpisodeCount(1, 1, (shown) => shown + 1)
      ..changeEpisodeCount(1, 2, (shown) => shown + 1)
      ..forgetEpisodeChanges([(season: 1, episode: 1)]);

    expect(container.read(watchedEpisodesMapProvider(showId)), {'1-2': 1});
  });

  // REV-193: after "Delete all" every later watch stayed hidden until the
  // page was closed.
  test('a movie watched again after "Delete all" shows up', () async {
    Map<String, dynamic> log(String at) => {
      'tmdb_id': movieId,
      'media_type': 'movie',
      'logged_at': at,
    };
    container.listen(movieWatchCountProvider(movieId), (_, __) {});
    logs.add([log('2026-10-01T20:00:00Z'), log('2026-10-12T20:00:00Z')]);
    await pumpEvents();

    container
        .read(movieWatchLogsProvider(movieId).notifier)
        .optimisticClearAll();
    expect(container.read(movieWatchCountProvider(movieId)), 0);

    // An old event still holding the logs keeps them hidden.
    logs.add([log('2026-10-01T20:00:00Z'), log('2026-10-12T20:00:00Z')]);
    await pumpEvents();
    expect(container.read(movieWatchCountProvider(movieId)), 0);

    logs.add([]);
    await pumpEvents();
    logs.add([log('2026-10-13T20:00:00Z')]);
    await pumpEvents();
    expect(container.read(movieWatchCountProvider(movieId)), 1);
  });

  // REV-195: the history store was keyed by tmdbId only, so a movie and a
  // show sharing one overwrote each other.
  test('a movie and a show with the same id keep their own history', () async {
    WatchHistory history(MediaKind type, int progress) => WatchHistory(
      userId: 'user-a',
      tmdbId: 1399,
      mediaType: type,
      status: WatchStatus.watching,
      progressSeconds: progress,
      lastWatchedAt: DateTime.utc(2026, 10, progress),
    );
    when(() => repository.syncWatchHistory('user-a')).thenAnswer((_) async {});
    when(() => repository.watchHistory('user-a')).thenAnswer(
      (_) =>
          Stream.value([history(MediaKind.movie, 1), history(MediaKind.tv, 2)]),
    );
    final movie = mediaWatchHistoryProvider((id: '1399', type: 'movie'));
    final show = mediaWatchHistoryProvider((id: '1399', type: 'tv'));
    container.listen(movie, (_, __) {});
    container.listen(show, (_, __) {});
    await container.read(watchHistoryStoreProvider.future);

    expect(container.read(movie).value?.progressSeconds, 1);
    expect(container.read(show).value?.progressSeconds, 2);
  });

  // REV-194: keyed by a WatchHistory object, every history save made a new
  // entry and a new query for each Continue Watching card.
  test('the same show and episode share one rewatch query', () async {
    when(
      () => repository.getHighestLoggedEpisode('user-a', showId),
    ).thenAnswer((_) async => (season: 2, episode: 5));
    ({int tmdbId, MediaKind mediaType, int? season, int? episode}) title(
      int episode,
    ) => (tmdbId: showId, mediaType: MediaKind.tv, season: 2, episode: episode);

    container.listen(isRewatchingProvider(title(1)), (_, __) {});
    container.listen(isRewatchingProvider(title(1)), (_, __) {});
    container.listen(isRewatchingProvider(title(5)), (_, __) {});

    expect(await container.read(isRewatchingProvider(title(1)).future), true);
    expect(await container.read(isRewatchingProvider(title(5)).future), false);
    verify(
      () => repository.getHighestLoggedEpisode('user-a', showId),
    ).called(2);
  });
}
