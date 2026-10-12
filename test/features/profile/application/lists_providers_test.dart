import 'dart:async';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/profile/data/lists_repository.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockListsRepository extends Mock implements ListsRepository {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockWatchHistoryRepository extends Mock
    implements WatchHistoryRepository {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

UserList _list(String id, {ListType type = ListType.custom}) => UserList(
  id: id,
  userId: 'user-a',
  name: id,
  type: type,
  createdAt: DateTime(2026),
);

// REV-69: deleting a list with Undo.
void main() {
  late MockListsRepository repo;
  late MockWatchHistoryRepository historyRepo;
  late StreamController<List<UserList>> dbLists;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = MockListsRepository();
    historyRepo = MockWatchHistoryRepository();
    dbLists = StreamController<List<UserList>>.broadcast();
    when(() => repo.syncUserLists(any())).thenAnswer((_) async {});
    when(() => repo.watchUserLists(any())).thenAnswer((_) => dbLists.stream);

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
        listsRepositoryProvider.overrideWithValue(repo),
        watchHistoryRepositoryProvider.overrideWithValue(historyRepo),
      ],
    );
    container.listen(userListsProvider, (_, __) {});
    await pumpEventQueue();
    dbLists.add([_list('a'), _list('b')]);
    await pumpEventQueue();
  });

  tearDown(() async {
    container.dispose();
    await dbLists.close();
  });

  List<String> visibleIds() =>
      container.read(userListsProvider).value!.map((l) => l.id).toList();

  test('undo brings the list back; a refresh meanwhile does not', () async {
    final undone = Completer<bool>();
    final delete = container
        .read(userListsProvider.notifier)
        .deleteWithUndo('a', undone: undone.future);
    expect(visibleIds(), ['b']);

    dbLists.add([_list('a'), _list('b')]); // a pull-to-refresh sync
    await pumpEventQueue();
    expect(visibleIds(), ['b']);

    undone.complete(true);
    await delete;
    expect(visibleIds(), ['a', 'b']);
    verifyNever(() => repo.deleteList(any()));
  });

  test('a failed delete brings the list back and rethrows', () async {
    when(() => repo.deleteList('a')).thenThrow(const NetworkFailure('offline'));

    await expectLater(
      container
          .read(userListsProvider.notifier)
          .deleteWithUndo('a', undone: Future.value(false)),
      throwsA(isA<NetworkFailure>()),
    );
    expect(visibleIds(), ['a', 'b']);
    verify(() => repo.syncUserLists('user-a')).called(greaterThan(1));
  });

  test('a deleted list is unpinned', () async {
    when(() => repo.deleteList('a')).thenAnswer((_) async {});
    await container.read(pinnedListIdsProvider.notifier).togglePin('a');

    await container
        .read(userListsProvider.notifier)
        .deleteWithUndo('a', undone: Future.value(false));

    expect(visibleIds(), ['b']);
    expect(container.read(pinnedListIdsProvider), isEmpty);
  });

  // REV-96: right after a fresh install the lists aren't synced yet.
  group('toggleWatchlist before the first sync', () {
    final media = MediaItem(
      tmdbId: 1,
      mediaType: MediaKind.movie,
      updatedAt: DateTime(2026),
    );

    setUp(() {
      registerFallbackValue(MediaKind.movie);
      registerFallbackValue(<String, dynamic>{});
      when(
        () => repo.addItemToList(
          listId: any(named: 'listId'),
          tmdbId: any(named: 'tmdbId'),
          mediaType: any(named: 'mediaType'),
          meta: any(named: 'meta'),
        ),
      ).thenAnswer((_) async {});
    });

    test('syncs once, then adds to the watchlist', () async {
      when(() => repo.watchUserLists(any())).thenAnswer(
        (_) => Stream.value([_list('a'), _list('w', type: ListType.watchlist)]),
      );

      await container.read(userListsProvider.notifier).toggleWatchlist(media);

      verify(
        () => repo.addItemToList(
          listId: 'w',
          tmdbId: 1,
          mediaType: MediaKind.movie,
          meta: any(named: 'meta'),
        ),
      ).called(1);
    });

    test('throws a NotFoundFailure if the list is still missing', () async {
      when(
        () => repo.watchUserLists(any()),
      ).thenAnswer((_) => Stream.value([_list('a')]));

      await expectLater(
        container.read(userListsProvider.notifier).toggleWatchlist(media),
        throwsA(isA<NotFoundFailure>()),
      );
    });
  });

  // REV-106: Restore goes through the notifier.
  group('dropped list', () {
    setUp(() {
      when(
        () => historyRepo.getDroppedItems(any()),
      ).thenAnswer((_) async => []);
    });

    test('a failed restore rethrows and the Dropped list reloads', () async {
      container.listen(droppedListProvider, (_, __) {});
      await container.read(droppedListProvider.future);
      when(
        () => historyRepo.restoreToContinueWatching('user-a', 7, 'movie'),
      ).thenThrow(const NetworkFailure('offline'));

      await expectLater(
        container
            .read(userListsProvider.notifier)
            .restoreFromDropped(7, MediaKind.movie),
        throwsA(isA<NetworkFailure>()),
      );
      await container.read(droppedListProvider.future);
      verify(() => historyRepo.getDroppedItems('user-a')).called(2);
    });
  });
}
