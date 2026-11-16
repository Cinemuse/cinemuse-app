import 'dart:async';

import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/core/application/l10n_provider.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/media/application/title_removals.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/data/watch_progress_repository.dart';
import 'package:cinemuse_app/features/media/domain/episode_item.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/video_player/application/helpers/player_history_manager.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockWatchProgressRepository extends Mock
    implements WatchProgressRepository {}

class _MockWatchHistoryRepository extends Mock
    implements WatchHistoryRepository {}

class _MockTmdbService extends Mock implements TmdbService {}

void main() {
  late _MockWatchProgressRepository repository;
  late ProviderContainer container;
  late PlayerHistoryManager manager;
  late List<String?> notices;

  PlayerHistoryManager managerFor(PlayerParams params, MediaKind kind) =>
      container.read(
        Provider<PlayerHistoryManager>(
          (ref) => PlayerHistoryManager(
            ref: ref,
            params: params,
            mediaItem: MediaItem(
              tmdbId: int.parse(params.queryId),
              mediaType: kind,
              updatedAt: DateTime(2026),
            ),
            onNotice: notices.add,
          ),
        ),
      );

  setUpAll(() {
    registerFallbackValue(
      MediaItem(tmdbId: 0, mediaType: MediaKind.movie, updatedAt: DateTime(0)),
    );
  });

  setUp(() {
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

    repository = _MockWatchProgressRepository();
    notices = [];
    container = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        supabaseClientProvider.overrideWithValue(client),
        watchProgressRepositoryProvider.overrideWithValue(repository),
        localizationsProvider.overrideWithValue(
          lookupAppLocalizations(const Locale('en')),
        ),
      ],
    );
    addTearDown(container.dispose);
    manager = managerFor(const PlayerParams('603', 'movie'), MediaKind.movie);
  });

  void saveFails(bool fails) {
    when(
      () => repository.updateProgress(
        userId: any(named: 'userId'),
        media: any(named: 'media'),
        progressSeconds: any(named: 'progressSeconds'),
        totalDuration: any(named: 'totalDuration'),
        season: any(named: 'season'),
        episode: any(named: 'episode'),
        series: any(named: 'series'),
        actualSecondsWatched: any(named: 'actualSecondsWatched'),
        initialPosition: any(named: 'initialPosition'),
      ),
    ).thenAnswer(
      (_) async => fails ? throw const NetworkFailure('offline') : null,
    );
  }

  Future<void> save([PlayerHistoryManager? saving]) =>
      (saving ?? manager).saveProgress(
        position: 1800,
        duration: 6000,
        actualSecondsWatched: 1800,
        initialPosition: 0,
        isCompletionLogged: false,
        onCompletionLogged: (_) {},
      );

  // REV-326: season 0 (the specials) was taken as "no season", so S0 E37
  // played as S1 E37.
  group('the episode to play', () {
    late _MockWatchHistoryRepository historyRepository;

    Future<PlayerParams> resolve(PlayerParams params) {
      final child = ProviderContainer(
        retry: noProviderRetry,
        parent: container,
        overrides: [
          watchHistoryRepositoryProvider.overrideWithValue(historyRepository),
        ],
      );
      addTearDown(child.dispose);
      return child.read(
        FutureProvider(
          (ref) => PlayerHistoryManager.resolveInitialParams(
            ref: ref,
            params: params,
          ),
          // Scoped, so it reads the child's fake history.
          dependencies: [watchHistoryRepositoryProvider],
        ).future,
      );
    }

    void historyAt(int season, int episode) =>
        when(
          () => historyRepository.getHistoryItem(any(), any(), any()),
        ).thenAnswer(
          (_) async => WatchHistory(
            userId: 'user-a',
            tmdbId: 1429,
            mediaType: MediaKind.tv,
            season: season,
            episode: episode,
            progressSeconds: 600,
            status: WatchStatus.watching,
            lastWatchedAt: DateTime(2026),
          ),
        );

    setUp(() => historyRepository = _MockWatchHistoryRepository());

    test('a special keeps its season 0', () async {
      historyAt(2, 4);

      final params = await resolve(
        const PlayerParams('1429', 'tv', season: 0, episode: 37),
      );

      expect((params.season, params.episode), (0, 37));
    });

    test('with no episode picked, a half-watched special resumes', () async {
      historyAt(0, 3);

      final params = await resolve(const PlayerParams('1429', 'tv'));

      expect((params.season, params.episode), (0, 3));
      expect(params.startPosition, 600);
    });

    test('a show with no episode yet starts at S1 E1', () async {
      historyAt(0, 0);

      final params = await resolve(const PlayerParams('1429', 'tv'));

      expect((params.season, params.episode), (1, 1));
    });
  });

  // DATA-03: offline the saves failed silently (logged only).
  test('tells once when saves fail, again after they worked', () async {
    const notSaved =
        "Progress not saved. Can't reach the server. Check your connection.";

    saveFails(true);
    await save();
    await save(); // Every 15 s while offline: no new message.
    expect(notices, [notSaved]);

    saveFails(false);
    await save();
    await save();
    expect(notices, [notSaved, null]);

    saveFails(true);
    await save();
    expect(notices, [notSaved, null, notSaved]);
  });

  // REV-346: the last save runs while the player closes, when its provider
  // can no longer read others.
  // Play pressed right after "Clear progress": the clear, sent when its
  // message closes, must not wipe the new spot.
  test(
    'a save made while a clear waits for its Undo is sent after it',
    () async {
      final sent = <String>[];
      when(
        () => repository.updateProgress(
          userId: any(named: 'userId'),
          media: any(named: 'media'),
          progressSeconds: any(named: 'progressSeconds'),
          totalDuration: any(named: 'totalDuration'),
          season: any(named: 'season'),
          episode: any(named: 'episode'),
          series: any(named: 'series'),
          actualSecondsWatched: any(named: 'actualSecondsWatched'),
          initialPosition: any(named: 'initialPosition'),
        ),
      ).thenAnswer((_) async => sent.add('save'));
      final undone = Completer<bool>();
      final clearing = container
          .read(titleRemovalsProvider)
          .removeUnlessUndone(
            title: 'movie-603',
            undone: undone.future,
            remove: () async => sent.add('clear'),
            showAgain: () {},
            action: 'clearProgress',
          );

      final saving = save();
      await Future<void>.delayed(Duration.zero);
      expect(sent, isEmpty);

      undone.complete(false);
      await Future.wait([clearing, saving]);
      expect(sent, ['clear', 'save']);
    },
  );

  test('saves the progress while the player closes', () async {
    saveFails(false);
    final player = Provider.autoDispose<PlayerHistoryManager>((ref) {
      final closing = PlayerHistoryManager(
        ref: ref,
        params: const PlayerParams('603', 'movie'),
        mediaItem: MediaItem(
          tmdbId: 603,
          mediaType: MediaKind.movie,
          updatedAt: DateTime(2026),
        ),
        onNotice: notices.add,
      );
      ref.onDispose(() => unawaited(save(closing)));
      return closing;
    });
    container.listen(player, (_, _) {}).close();
    await container.pump(); // the player closes
    await Future<void>.delayed(Duration.zero); // the save runs

    verify(
      () => repository.updateProgress(
        userId: 'user-a',
        media: any(named: 'media'),
        progressSeconds: 1800,
        totalDuration: 6000,
        season: any(named: 'season'),
        episode: any(named: 'episode'),
        series: any(named: 'series'),
        actualSecondsWatched: any(named: 'actualSecondsWatched'),
        initialPosition: any(named: 'initialPosition'),
      ),
    ).called(1);
  });

  // REV-310: offline, "Next episode" left the episode unwatched silently.
  test('"Next episode" offline: returns the not-watched message', () async {
    when(
      () => repository.completeEpisode(
        userId: any(named: 'userId'),
        tmdbId: any(named: 'tmdbId'),
        season: any(named: 'season'),
        episode: any(named: 'episode'),
        durationWatched: any(named: 'durationWatched'),
        series: any(named: 'series'),
      ),
    ).thenThrow(const NetworkFailure('offline'));
    final tvManager = managerFor(
      const PlayerParams('1399', 'tv', season: 1, episode: 2),
      MediaKind.tv,
    );

    final message = await tvManager.markCurrentEpisodeCompleted(
      position: 3000,
      duration: 3600,
    );

    expect(
      message,
      "Episode not marked as watched. Can't reach the server. "
      'Check your connection.',
    );
  });

  // An add-on's 30-second error video shows the "Next episode" button at
  // once: pressing it must not tick the episode, like the normal save,
  // which ignores anything under a minute.
  test('"Next episode" on a video under a minute ticks nothing', () async {
    final tvManager = managerFor(
      const PlayerParams('1399', 'tv', season: 1, episode: 2),
      MediaKind.tv,
    );

    await tvManager.markCurrentEpisodeCompleted(position: 20, duration: 30);

    verifyNever(
      () => repository.completeEpisode(
        userId: any(named: 'userId'),
        tmdbId: any(named: 'tmdbId'),
        season: any(named: 'season'),
        episode: any(named: 'episode'),
        durationWatched: any(named: 'durationWatched'),
        series: any(named: 'series'),
      ),
    );
  });

  test('the next episode carries its name from TMDB\'s season', () async {
    final tmdb = _MockTmdbService();
    when(() => tmdb.getSeasonEpisodes(1399, 1)).thenAnswer(
      (_) async => EpisodeItem.listFromTmdbSeason({
        'episodes': [
          {'episode_number': 2, 'name': 'The Kingsroad'},
          {'episode_number': 3, 'name': 'Lord Snow'},
        ],
      }, 1),
    );
    // Its own container: the manager reads TMDB from its provider's home
    // container, which a child container's override doesn't reach.
    final withTmdb = ProviderContainer(
      retry: noProviderRetry,
      overrides: [tmdbServiceProvider.overrideWithValue(tmdb)],
    );
    addTearDown(withTmdb.dispose);
    final series = MediaItem.fromTmdbDetails({
      'id': 1399,
      'status': 'Ended',
      'seasons': [
        {'season_number': 1, 'episode_count': 3, 'air_date': '2011-04-17'},
      ],
      'last_episode_to_air': {'season_number': 1, 'episode_number': 3},
    }, MediaKind.tv);
    final tvManager = withTmdb.read(
      Provider<PlayerHistoryManager>(
        (ref) => PlayerHistoryManager(
          ref: ref,
          params: const PlayerParams('1399', 'tv', season: 1, episode: 2),
          mediaItem: series,
          series: series,
          onNotice: notices.add,
        ),
      ),
    );

    final next = await tvManager.calculateNextEpisode();

    expect((next!.season, next.episode, next.title), (1, 3, 'Lord Snow'));
  });
}
