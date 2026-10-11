import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/profile/application/user_data_sync_service.dart';
import 'package:cinemuse_app/features/profile/data/lists_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockListsRepository extends Mock implements ListsRepository {}

class MockWatchHistoryRepository extends Mock
    implements WatchHistoryRepository {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

// REV-75: the pull-to-refresh sync used to swallow failures.
void main() {
  late MockListsRepository lists;
  late MockWatchHistoryRepository history;
  late ProviderContainer container;

  setUp(() {
    lists = MockListsRepository();
    history = MockWatchHistoryRepository();

    final auth = MockGoTrueClient();
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
    final client = MockSupabaseClient();
    when(() => client.auth).thenReturn(auth);

    container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => AuthService(client)),
        listsRepositoryProvider.overrideWithValue(lists),
        watchHistoryRepositoryProvider.overrideWithValue(history),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('syncs history and lists for the signed-in user', () async {
    when(() => history.syncWatchHistory(any())).thenAnswer((_) async {});
    when(() => lists.syncUserLists(any())).thenAnswer((_) async {});

    await container.read(userDataSyncServiceProvider).syncNow();

    verify(() => history.syncWatchHistory('user-a')).called(1);
    verify(() => lists.syncUserLists('user-a')).called(1);
  });

  test('a failed sync is thrown, after the other one still ran', () async {
    when(
      () => history.syncWatchHistory(any()),
    ).thenAnswer((_) async => throw const NetworkFailure('offline'));
    when(() => lists.syncUserLists(any())).thenAnswer((_) async {});

    await expectLater(
      container.read(userDataSyncServiceProvider).syncNow(),
      throwsA(isA<NetworkFailure>()),
    );
    verify(() => lists.syncUserLists('user-a')).called(1);
  });
}
