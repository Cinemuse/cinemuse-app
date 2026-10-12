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

  late StreamController<List<Map<String, dynamic>>> logs;
  late bool isLogStreamCancelled;
  late ProviderContainer container;

  setUp(() {
    isLogStreamCancelled = false;
    logs = StreamController<List<Map<String, dynamic>>>(
      onCancel: () => isLogStreamCancelled = true,
    );
    addTearDown(logs.close);

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

    container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => AuthService(client)),
        watchHistoryRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  });

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
}
