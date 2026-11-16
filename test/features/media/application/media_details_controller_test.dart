import 'dart:async';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/features/home/application/continue_watching_service.dart';
import 'package:cinemuse_app/features/home/application/home_providers.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/application/media_details_controller.dart';
import 'package:cinemuse_app/features/media/application/watch_history_store.dart';
import 'package:cinemuse_app/features/media/data/watch_logs_repository.dart';
import 'package:cinemuse_app/features/media/data/watch_progress_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

class _MockWatchLogsRepository extends Mock implements WatchLogsRepository {}

class _MockWatchProgressRepository extends Mock
    implements WatchProgressRepository {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

/// A Supabase client signed in as 'user-a'.
SupabaseClient _signedInClient() {
  final user = User(
    id: 'user-a',
    appMetadata: {},
    userMetadata: {},
    aud: '',
    createdAt: '',
  );
  final auth = _MockGoTrueClient();
  when(() => auth.currentUser).thenReturn(user);
  when(
    () => auth.currentSession,
  ).thenReturn(Session(accessToken: 'token', tokenType: 'bearer', user: user));
  when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
  final client = _MockSupabaseClient();
  when(() => client.auth).thenReturn(auth);
  return client;
}

void main() {
  const tmdbId = 1396;
  setUpAll(() {
    registerFallbackValue(
      MediaItem(tmdbId: 0, mediaType: MediaKind.tv, updatedAt: DateTime(0)),
    );
  });
  final details = MediaItem.fromTmdbDetails({
    'id': tmdbId,
    'seasons': <dynamic>[
      {'season_number': 1, 'episode_count': 2},
      {'season_number': 2, 'episode_count': 3},
    ],
  }, MediaKind.tv);

  WatchHistory history({required WatchStatus status}) => WatchHistory(
    userId: 'user-a',
    tmdbId: tmdbId,
    mediaType: MediaKind.tv,
    status: status,
    progressSeconds: 0,
    lastWatchedAt: DateTime.utc(2026, 10, 1),
    season: 1,
    episode: 2,
  );

  // REV-190: opening a show's page used to put it back in Continue Watching
  // at the next season, even when dropped or not aired yet.
  test('a fully watched season opens the next one without writing', () {
    final logs = _MockWatchLogsRepository();
    final progress = _MockWatchProgressRepository();
    final container = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        watchLogsRepositoryProvider.overrideWithValue(logs),
        watchProgressRepositoryProvider.overrideWithValue(progress),
        watchedEpisodesMapProvider(
          tmdbId,
        ).overrideWithValue({'1-1': 1, '1-2': 1}),
      ],
    );
    addTearDown(container.dispose);

    final season = container
        .read(mediaDetailsControllerProvider.notifier)
        .resolveInitialSeason(
          tmdbId: tmdbId,
          series: details,
          watchHistory: history(status: WatchStatus.dropped),
        );

    expect(season, 2);
    verifyZeroInteractions(logs);
    verifyZeroInteractions(progress);
  });

  group('"Remove all" on a show', () {
    late StreamController<List<Map<String, dynamic>>> showLogs;
    late _MockWatchLogsRepository logs;
    late ProviderContainer container;
    late Completer<bool> undone;

    Map<String, dynamic> log(String id, int episode) => {
      'id': id,
      'user_id': 'user-a',
      'tmdb_id': tmdbId,
      'media_type': 'tv',
      'season': 1,
      'episode': episode,
      'logged_at': '2026-10-0${episode}T20:00:00Z',
    };

    Map<String, int> shown() =>
        container.read(watchedEpisodesMapProvider(tmdbId));

    Future<void> removeAll() => container
        .read(mediaDetailsControllerProvider.notifier)
        .deleteAllSeriesLogs(tmdbId: tmdbId, undone: undone.future);

    Future<void> deleteCalled() =>
        logs.deleteAllSeriesLogs(userId: 'user-a', tmdbId: tmdbId);

    setUp(() async {
      showLogs = StreamController<List<Map<String, dynamic>>>.broadcast();
      addTearDown(showLogs.close);
      undone = Completer<bool>();
      final client = _signedInClient();

      logs = _MockWatchLogsRepository();
      when(
        () => logs.watchTitleLogs('user-a', tmdbId, 'tv'),
      ).thenAnswer((_) => showLogs.stream);
      when(deleteCalled).thenAnswer((_) async {});

      container = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          supabaseClientProvider.overrideWithValue(client),
          watchLogsRepositoryProvider.overrideWithValue(logs),
          watchProgressRepositoryProvider.overrideWithValue(
            _MockWatchProgressRepository(),
          ),
          mediaDetailsProvider.overrideWith((ref, args) async => null),
        ],
      );
      addTearDown(container.dispose);
      container.listen(watchedEpisodesMapProvider(tmdbId), (_, _) {});
      showLogs.add([log('a', 1), log('b', 2)]);
      await container.pump();
      await Future<void>.delayed(Duration.zero);
    });

    test(
      'hides every watch at once; Undo brings them back, deletes nothing',
      () async {
        final removal = removeAll();
        expect(shown(), isEmpty);

        undone.complete(true);
        await removal;

        expect(shown(), {'1-1': 1, '1-2': 1});
        verifyNever(deleteCalled);
      },
    );

    test(
      'when the message closes without Undo, the watches are deleted',
      () async {
        final removal = removeAll();
        verifyNever(deleteCalled);

        undone.complete(false);
        await removal;

        verify(deleteCalled).called(1);
        expect(shown(), isEmpty);
      },
    );

    test('a failed removal brings the watches back and says why', () async {
      when(deleteCalled).thenThrow(const NetworkFailure('offline'));
      final removal = removeAll();
      undone.complete(false);

      await expectLater(removal, throwsA(isA<NetworkFailure>()));
      expect(shown(), {'1-1': 1, '1-2': 1});
    });

    // The removal takes every watch of the show, so an episode marked
    // while the message is up is saved only after it.
    test('an episode marked meanwhile shows, and is saved after it', () async {
      when(
        () => logs.logMultipleEpisodes(
          userId: any(named: 'userId'),
          tmdbId: any(named: 'tmdbId'),
          episodes: any(named: 'episodes'),
          series: any(named: 'series'),
          loggedAt: any(named: 'loggedAt'),
        ),
      ).thenAnswer((_) async {});
      final removal = removeAll();
      final mark = container
          .read(mediaDetailsControllerProvider.notifier)
          .logEpisodeWatch(tmdbId: tmdbId, season: 1, episode: 3);
      await Future<void>.delayed(Duration.zero);

      expect(shown(), {'1-3': 1});
      verifyNever(
        () => logs.logMultipleEpisodes(
          userId: any(named: 'userId'),
          tmdbId: any(named: 'tmdbId'),
          episodes: any(named: 'episodes'),
          series: any(named: 'series'),
          loggedAt: any(named: 'loggedAt'),
        ),
      );

      undone.complete(false);
      await Future.wait([removal, mark]);
      verifyInOrder([
        deleteCalled,
        () => logs.logMultipleEpisodes(
          userId: 'user-a',
          tmdbId: tmdbId,
          episodes: [(season: 1, episode: 3)],
          series: any(named: 'series'),
          loggedAt: any(named: 'loggedAt'),
        ),
      ]);
    });
  });

  group('"Remove one" and "Remove all" on an episode or a movie', () {
    const movieId = 27205;
    late _MockWatchLogsRepository logs;
    late ProviderContainer container;
    late Completer<bool> undone;

    Map<String, dynamic> log(String id, String type, int day) => {
      'id': id,
      'user_id': 'user-a',
      'tmdb_id': type == 'tv' ? tmdbId : movieId,
      'media_type': type,
      'season': type == 'tv' ? 1 : null,
      'episode': type == 'tv' ? 1 : null,
      'logged_at': '2026-10-0${day}T20:00:00Z',
    };

    MediaDetailsController controller() =>
        container.read(mediaDetailsControllerProvider.notifier);
    int episodeShown() =>
        container.read(watchedEpisodesMapProvider(tmdbId))['1-1'] ?? 0;
    int movieShown() =>
        container.read(movieWatchLogsProvider(movieId)).value!.length;

    Future<void> episodeDeleteOne() => logs.deleteLatestEpisodeLog(
      userId: 'user-a',
      tmdbId: tmdbId,
      season: 1,
      episode: 1,
    );
    Future<void> episodeDeleteAll() => logs.deleteAllEpisodeLogs(
      userId: 'user-a',
      tmdbId: tmdbId,
      season: 1,
      episode: 1,
    );
    Future<void> movieDeleteOne() =>
        logs.deleteLatestMovieLog(userId: 'user-a', tmdbId: movieId);
    Future<void> movieDeleteAll() =>
        logs.deleteAllMovieLogs(userId: 'user-a', tmdbId: movieId);
    Future<void> movieLogged() => logs.logMovieWatch(
      userId: any(named: 'userId'),
      tmdbId: any(named: 'tmdbId'),
      loggedAt: any(named: 'loggedAt'),
      isNow: any(named: 'isNow'),
    );
    Future<void> episodesLogged() => logs.logMultipleEpisodes(
      userId: any(named: 'userId'),
      tmdbId: any(named: 'tmdbId'),
      episodes: any(named: 'episodes'),
      series: any(named: 'series'),
      loggedAt: any(named: 'loggedAt'),
    );

    setUp(() async {
      undone = Completer<bool>();
      logs = _MockWatchLogsRepository();
      // Episode 1 and the movie are each watched twice.
      when(() => logs.watchTitleLogs('user-a', tmdbId, 'tv')).thenAnswer(
        (_) => Stream.value([log('e1', 'tv', 1), log('e2', 'tv', 2)]),
      );
      when(() => logs.watchTitleLogs('user-a', movieId, 'movie')).thenAnswer(
        (_) => Stream.value([log('m1', 'movie', 1), log('m2', 'movie', 2)]),
      );
      for (final call in [
        episodeDeleteOne,
        episodeDeleteAll,
        movieDeleteOne,
        movieDeleteAll,
        movieLogged,
        episodesLogged,
      ]) {
        when(call).thenAnswer((_) async {});
      }

      container = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          supabaseClientProvider.overrideWithValue(_signedInClient()),
          watchLogsRepositoryProvider.overrideWithValue(logs),
          watchProgressRepositoryProvider.overrideWithValue(
            _MockWatchProgressRepository(),
          ),
          mediaDetailsProvider.overrideWith((ref, args) async => null),
        ],
      );
      addTearDown(container.dispose);
      container.listen(watchedEpisodesMapProvider(tmdbId), (_, _) {});
      container.listen(movieWatchLogsProvider(movieId), (_, _) {});
      await container.pump();
      await Future<void>.delayed(Duration.zero);
    });

    test('an episode\'s "Remove one": hidden at once; Undo brings it back, '
        'deletes nothing', () async {
      final removal = controller().deleteLatestEpisodeLog(
        tmdbId: tmdbId,
        season: 1,
        episode: 1,
        undone: undone.future,
      );
      expect(episodeShown(), 1);

      undone.complete(true);
      await removal;

      expect(episodeShown(), 2);
      verifyNever(episodeDeleteOne);
    });

    test('an episode\'s "Remove all" is deleted when the message closes '
        'without Undo', () async {
      final removal = controller().deleteAllEpisodeLogs(
        tmdbId: tmdbId,
        season: 1,
        episode: 1,
        undone: undone.future,
      );
      expect(episodeShown(), 0);
      verifyNever(episodeDeleteAll);

      undone.complete(false);
      await removal;

      verify(episodeDeleteAll).called(1);
      expect(episodeShown(), 0);
    });

    test(
      'a failed episode removal brings the watch back and says why',
      () async {
        when(episodeDeleteOne).thenThrow(const NetworkFailure('offline'));
        final removal = controller().deleteLatestEpisodeLog(
          tmdbId: tmdbId,
          season: 1,
          episode: 1,
          undone: undone.future,
        );
        undone.complete(false);

        await expectLater(removal, throwsA(isA<NetworkFailure>()));
        expect(episodeShown(), 2);
      },
    );

    // Undo brings back only what the removal hid: the new watch stays.
    test('the episode marked again meanwhile, then Undo: all three watches '
        'show', () async {
      final removal = controller().deleteAllEpisodeLogs(
        tmdbId: tmdbId,
        season: 1,
        episode: 1,
        undone: undone.future,
      );
      final mark = controller().logEpisodeWatch(
        tmdbId: tmdbId,
        season: 1,
        episode: 1,
      );
      expect(episodeShown(), 1);

      undone.complete(true);
      await Future.wait([removal, mark]);

      expect(episodeShown(), 3);
      verifyNever(episodeDeleteAll);
    });

    test('a movie\'s "Remove one": hidden at once; Undo brings it back, '
        'deletes nothing', () async {
      final removal = controller().deleteLatestMovieLog(
        tmdbId: movieId,
        undone: undone.future,
      );
      expect(movieShown(), 1);

      undone.complete(true);
      await removal;

      expect(movieShown(), 2);
      verifyNever(movieDeleteOne);
    });

    test('a movie\'s "Remove all" is deleted when the message closes without '
        'Undo; a failure brings the watches back', () async {
      final removal = controller().deleteAllMovieLogs(
        tmdbId: movieId,
        undone: undone.future,
      );
      expect(movieShown(), 0);
      verifyNever(movieDeleteAll);
      undone.complete(false);
      await removal;
      verify(movieDeleteAll).called(1);

      when(movieDeleteAll).thenThrow(const NetworkFailure('offline'));
      final failing = controller().deleteAllMovieLogs(
        tmdbId: movieId,
        undone: Future.value(false),
      );
      await expectLater(failing, throwsA(isA<NetworkFailure>()));
      expect(movieShown(), 2);
    });

    // "Remove one" deletes the newest watch the server has when it is
    // sent, so a watch logged meanwhile must be saved after it.
    test('a movie watched again meanwhile shows, and is saved after the '
        'removal', () async {
      final removal = controller().deleteLatestMovieLog(
        tmdbId: movieId,
        undone: undone.future,
      );
      final mark = controller().logMovieWatch(tmdbId: movieId);
      await Future<void>.delayed(Duration.zero);

      expect(movieShown(), 2);
      verifyNever(movieLogged);

      undone.complete(false);
      await Future.wait([removal, mark]);
      verifyInOrder([movieDeleteOne, movieLogged]);
    });
  });

  group('"Clear progress" (Home card and title page)', () {
    const movieId = 27205;
    late _MockWatchProgressRepository progress;
    late ProviderContainer container;
    late Completer<bool> undone;

    final movie = WatchHistory(
      userId: 'user-a',
      tmdbId: movieId,
      mediaType: MediaKind.movie,
      status: WatchStatus.watching,
      progressSeconds: 4360,
      totalDuration: 9000,
      lastWatchedAt: DateTime.utc(2026, 10, 20),
    );
    final show = WatchHistory(
      userId: 'user-a',
      tmdbId: tmdbId,
      mediaType: MediaKind.tv,
      status: WatchStatus.watching,
      progressSeconds: 600,
      totalDuration: 2700,
      lastWatchedAt: DateTime.utc(2026, 10, 10),
      season: 2,
      episode: 5,
    );

    WatchHistory? shown(WatchHistory row) =>
        container.read(shownWatchHistoryProvider).value?[row.titleKey];

    List<String> continueWatching() => [
      for (final row in container.read(continueWatchingProvider).value!)
        row.titleKey,
    ];

    Future<void> clear(WatchHistory row) => container
        .read(mediaDetailsControllerProvider.notifier)
        .clearProgress(row, undone: undone.future);

    Future<void> clearCalled(WatchHistory row) => progress.clearProgress(
      userId: 'user-a',
      tmdbId: row.tmdbId,
      mediaType: row.mediaType.name,
    );

    setUp(() async {
      undone = Completer<bool>();
      progress = _MockWatchProgressRepository();
      when(
        () => progress.clearProgress(
          userId: any(named: 'userId'),
          tmdbId: any(named: 'tmdbId'),
          mediaType: any(named: 'mediaType'),
        ),
      ).thenAnswer((_) async {});
      container = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          supabaseClientProvider.overrideWithValue(_signedInClient()),
          watchProgressRepositoryProvider.overrideWithValue(progress),
          watchLogsRepositoryProvider.overrideWithValue(
            _MockWatchLogsRepository(),
          ),
          watchHistoryStoreProvider.overrideWith(
            (ref) => Stream.value({movie.titleKey: movie, show.titleKey: show}),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(continueWatchingProvider, (_, _) {});
      await container.read(watchHistoryStoreProvider.future);
    });

    test('a movie leaves Continue Watching at once; Undo brings it back and '
        'sends nothing', () async {
      final clearing = clear(movie);
      expect(continueWatching(), ['tv-1396']);
      expect(shown(movie)!.progressSeconds, 0);

      undone.complete(true);
      await clearing;

      expect(continueWatching(), ['movie-27205', 'tv-1396']);
      expect(shown(movie)!.progressSeconds, 4360);
      verifyNever(() => clearCalled(movie));
    });

    test('a show stays on its episode from the start; the clear is sent '
        'when the message closes without Undo', () async {
      final clearing = clear(show);
      expect(shown(show)!.progressSeconds, 0);
      expect(shown(show)!.episode, 5);
      expect(continueWatching(), ['movie-27205', 'tv-1396']);
      verifyNever(() => clearCalled(show));

      undone.complete(false);
      await clearing;

      verify(() => clearCalled(show)).called(1);
      expect(shown(show)!.progressSeconds, 0);
    });

    test('a failed clear brings the progress back and says why', () async {
      when(() => clearCalled(movie)).thenThrow(const NetworkFailure('offline'));
      final clearing = clear(movie);
      undone.complete(false);

      await expectLater(clearing, throwsA(isA<NetworkFailure>()));
      expect(shown(movie)!.progressSeconds, 4360);
      expect(continueWatching(), ['movie-27205', 'tv-1396']);
    });

    test('"Stop Watching" pressed meanwhile is sent after the clear', () async {
      Future<void> dropCalled() =>
          progress.dropFromContinueWatching('user-a', tmdbId, 'tv');
      when(dropCalled).thenAnswer((_) async {});
      final clearing = clear(show);
      final drop = container
          .read(mediaDetailsControllerProvider.notifier)
          .dropTitle(show);
      await Future<void>.delayed(Duration.zero);
      verifyNever(dropCalled);

      undone.complete(false);
      await Future.wait([clearing, drop]);
      verifyInOrder([() => clearCalled(show), dropCalled]);
    });
  });

  group('"Stop rewatching" (Home card)', () {
    const movieId = 27205;
    late _MockWatchProgressRepository progress;
    late ProviderContainer container;
    late Completer<bool> undone;

    final movie = WatchHistory(
      userId: 'user-a',
      tmdbId: movieId,
      mediaType: MediaKind.movie,
      status: WatchStatus.watching,
      progressSeconds: 4360,
      totalDuration: 9000,
      lastWatchedAt: DateTime.utc(2026, 10, 20),
    );
    // Rewatching S1 E3; the user had logged up to S2 E6 before.
    final show = WatchHistory(
      userId: 'user-a',
      tmdbId: tmdbId,
      mediaType: MediaKind.tv,
      status: WatchStatus.watching,
      progressSeconds: 600,
      totalDuration: 2700,
      lastWatchedAt: DateTime.utc(2026, 10, 10),
      season: 1,
      episode: 3,
    );
    const end = (season: 2, episode: 7, finished: false);

    WatchHistory? shown(WatchHistory row) =>
        container.read(shownWatchHistoryProvider).value?[row.titleKey];

    List<String> continueWatching() => [
      for (final row in container.read(continueWatchingProvider).value!)
        row.titleKey,
    ];

    Future<void> cancel(WatchHistory row) => container
        .read(continueWatchingServiceProvider)
        .cancelRewatch(row, undone: undone.future);

    Future<void> cancelCalled(WatchHistory row) => progress.cancelRewatch(
      'user-a',
      row.tmdbId,
      row.mediaType.name,
      end: row.mediaType == MediaKind.movie ? null : end,
    );

    setUp(() async {
      undone = Completer<bool>();
      progress = _MockWatchProgressRepository();
      when(
        () => progress.rewatchEnd('user-a', tmdbId),
      ).thenAnswer((_) async => end);
      when(
        () =>
            progress.cancelRewatch(any(), any(), any(), end: any(named: 'end')),
      ).thenAnswer((_) async {});
      container = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          supabaseClientProvider.overrideWithValue(_signedInClient()),
          watchProgressRepositoryProvider.overrideWithValue(progress),
          watchLogsRepositoryProvider.overrideWithValue(
            _MockWatchLogsRepository(),
          ),
          watchHistoryStoreProvider.overrideWith(
            (ref) => Stream.value({movie.titleKey: movie, show.titleKey: show}),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(continueWatchingProvider, (_, _) {});
      await container.read(watchHistoryStoreProvider.future);
    });

    test('a show goes back to the episode after the highest logged one at '
        'once, first in the row; Undo brings the rewatch back and sends '
        'nothing', () async {
      final cancelling = cancel(show);
      await Future<void>.delayed(Duration.zero);
      final now = shown(show)!;
      expect((now.season, now.episode, now.progressSeconds), (2, 7, 0));
      expect(continueWatching(), ['tv-1396', 'movie-27205']);

      undone.complete(true);
      await cancelling;

      final back = shown(show)!;
      expect((back.season, back.episode, back.progressSeconds), (1, 3, 600));
      expect(continueWatching(), ['movie-27205', 'tv-1396']);
      verifyNever(() => cancelCalled(show));
    });

    test('a finished show leaves Continue Watching at once', () async {
      when(
        () => progress.rewatchEnd('user-a', tmdbId),
      ).thenAnswer((_) async => (season: 2, episode: 6, finished: true));
      final cancelling = cancel(show);
      await Future<void>.delayed(Duration.zero);

      expect(continueWatching(), ['movie-27205']);
      expect(shown(show)!.episode, 6);

      undone.complete(true);
      await cancelling;
    });

    test('a movie leaves at once; the cancel is sent when the message '
        'closes without Undo', () async {
      final cancelling = cancel(movie);
      expect(continueWatching(), ['tv-1396']);
      expect(shown(movie)!.isCompleted, isTrue);
      verifyNever(() => cancelCalled(movie));

      undone.complete(false);
      await cancelling;

      verify(() => cancelCalled(movie)).called(1);
      verifyNever(() => progress.rewatchEnd(any(), any()));
    });

    test('a failed cancel brings the rewatch back and says why', () async {
      when(() => cancelCalled(show)).thenThrow(const NetworkFailure('offline'));
      final cancelling = cancel(show);
      undone.complete(false);

      await expectLater(cancelling, throwsA(isA<NetworkFailure>()));
      final back = shown(show)!;
      expect((back.season, back.episode, back.progressSeconds), (1, 3, 600));
    });

    test(
      '"Clear Progress" pressed meanwhile is sent after the cancel',
      () async {
        Future<void> clearCalled() => progress.clearProgress(
          userId: 'user-a',
          tmdbId: tmdbId,
          mediaType: 'tv',
        );
        when(clearCalled).thenAnswer((_) async {});
        final cancelling = cancel(show);
        await Future<void>.delayed(Duration.zero);
        final clearing = container
            .read(continueWatchingServiceProvider)
            .clearProgress(show, undone: Future.value(false));
        await Future<void>.delayed(Duration.zero);
        verifyNever(clearCalled);

        undone.complete(false);
        await Future.wait([cancelling, clearing]);
        verifyInOrder([() => cancelCalled(show), clearCalled]);
      },
    );
  });
}
