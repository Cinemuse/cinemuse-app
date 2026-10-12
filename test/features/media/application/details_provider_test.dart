import 'dart:async';

import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
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

    final repository = _MockWatchHistoryRepository();
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

  // REV-191: the log providers were never disposed, so every title opened
  // kept a Supabase realtime channel open for the whole session.
  test('the movie log stream closes once nothing watches it', () async {
    final subscription = container.listen(
      movieWatchCountProvider(movieId),
      (_, __) {},
    );
    logs.add([
      {
        'tmdb_id': movieId,
        'media_type': 'movie',
        'logged_at': '2026-10-12T20:00:00Z',
      },
    ]);
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(movieWatchCountProvider(movieId)), 1);

    subscription.close();
    await container.pump();

    expect(isLogStreamCancelled, isTrue);
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
}
