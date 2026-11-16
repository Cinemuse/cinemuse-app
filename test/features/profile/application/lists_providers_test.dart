import 'dart:async';

import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/data/watch_progress_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/profile/application/pinned_list_ids_provider.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/profile/data/profile_repository.dart';
import 'package:cinemuse_app/features/profile/domain/profile.dart';
import 'package:cinemuse_app/features/profile/data/lists_repository.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide ListType;
import 'package:cinemuse_app/core/application/provider_retry.dart';

class MockListsRepository extends Mock implements ListsRepository {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockWatchHistoryRepository extends Mock
    implements WatchHistoryRepository {}

class MockWatchProgressRepository extends Mock
    implements WatchProgressRepository {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockMediaRepository extends Mock implements MediaRepository {}

UserList _list(
  String id, {
  ListType type = ListType.custom,
  List<UserListItem> items = const [],
}) => UserList(
  id: id,
  userId: 'user-a',
  name: id,
  type: type,
  createdAt: DateTime(2026),
  items: items,
);

// REV-69: deleting a list with Undo.
void main() {
  late MockListsRepository repo;
  late MockWatchHistoryRepository historyRepo;
  late MockWatchProgressRepository progressRepo;
  late MockProfileRepository profiles;
  late MockMediaRepository cache;
  late StreamController<List<UserList>> dbLists;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = MockListsRepository();
    historyRepo = MockWatchHistoryRepository();
    progressRepo = MockWatchProgressRepository();
    profiles = MockProfileRepository();
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(MediaKind.movie);
    when(
      () => profiles.patchPreferences(any(), any()),
    ).thenAnswer((_) async {});
    // The title cache, kept off the real database on disk.
    cache = MockMediaRepository();
    registerFallbackValue(
      MediaItem(tmdbId: 0, mediaType: MediaKind.movie, updatedAt: DateTime(0)),
    );
    when(() => cache.saveMediaItem(any())).thenAnswer((_) async {});
    when(() => cache.getMediaItem(any(), any())).thenAnswer((_) async => null);
    final profile = Profile(
      id: 'user-a',
      preferences: {
        PinnedListIdsNotifier.prefsKey: ['a', 'b'],
      },
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
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
      retry: noProviderRetry,
      overrides: [
        supabaseClientProvider.overrideWithValue(client),
        listsRepositoryProvider.overrideWithValue(repo),
        mediaRepositoryProvider.overrideWithValue(cache),
        watchHistoryRepositoryProvider.overrideWithValue(historyRepo),
        watchProgressRepositoryProvider.overrideWithValue(progressRepo),
        profileStreamProvider.overrideWith((ref) => Stream.value(profile)),
        profileRepositoryProvider.overrideWithValue(profiles),
      ],
    );
    container.listen(userListsProvider, (_, _) {});
    container.listen(pinnedListIdsProvider, (_, _) {});
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

  // REV-203: the heart icon read the notifier, so it never followed changes.
  test('isInSystemListProvider follows the lists as they change', () async {
    final key = (tmdbId: 7, mediaType: MediaKind.tv, type: ListType.favorites);
    final seen = <bool>[];
    container.listen(
      isInSystemListProvider(key),
      (_, next) => seen.add(next),
      fireImmediately: true,
    );

    UserList favorites({required bool withItem}) => UserList(
      id: 'fav',
      userId: 'user-a',
      name: 'fav',
      type: ListType.favorites,
      createdAt: DateTime(2026),
      items: [
        if (withItem)
          UserListItem(
            listId: 'fav',
            tmdbId: 7,
            mediaType: MediaKind.tv,
            addedAt: DateTime(2026),
          ),
        // Same id, other type: must not count (REV-177).
        UserListItem(
          listId: 'fav',
          tmdbId: 7,
          mediaType: MediaKind.movie,
          addedAt: DateTime(2026),
        ),
      ],
    );
    dbLists.add([favorites(withItem: true)]);
    await pumpEventQueue();
    dbLists.add([favorites(withItem: false)]);
    await pumpEventQueue();

    expect(seen, [false, true, false]);
  });

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
  });

  test('a deleted list is unpinned', () async {
    when(() => repo.deleteList('a')).thenAnswer((_) async {});

    await container
        .read(userListsProvider.notifier)
        .deleteWithUndo('a', undone: Future.value(false));

    expect(visibleIds(), ['b']);
    expect(container.read(pinnedListIdsProvider), {'b'});
    verify(
      () => profiles.patchPreferences('user-a', {
        PinnedListIdsNotifier.prefsKey: ['b'],
      }),
    ).called(1);
  });

  test('a failed unpin still deletes the list', () async {
    when(() => repo.deleteList('a')).thenAnswer((_) async {});
    when(
      () => profiles.patchPreferences(any(), any()),
    ).thenThrow(const NetworkFailure('offline'));

    await container
        .read(userListsProvider.notifier)
        .deleteWithUndo('a', undone: Future.value(false));

    expect(visibleIds(), ['b']);
  });

  group('a title taken out of a list, with Undo', () {
    UserListItem item(int tmdbId) => UserListItem(
      listId: 'a',
      tmdbId: tmdbId,
      mediaType: MediaKind.movie,
      addedAt: DateTime(2026),
    );
    final withTitles = _list('a', items: [item(1), item(2)]);

    setUp(() async {
      dbLists.add([withTitles]);
      await pumpEventQueue();
    });

    List<int> visibleTitles() => container
        .read(userListsProvider)
        .value!
        .single
        .items
        .map((i) => i.tmdbId)
        .toList();

    Future<void> remove(Future<bool> undone) => container
        .read(userListsProvider.notifier)
        .removeItemWithUndo('a', 1, MediaKind.movie, undone: undone);

    test('undo brings it back in its place; a refresh meanwhile does '
        'not', () async {
      final undone = Completer<bool>();
      final removal = remove(undone.future);
      expect(visibleTitles(), [2]);

      dbLists.add([withTitles]); // a pull-to-refresh sync
      await pumpEventQueue();
      expect(visibleTitles(), [2]);

      undone.complete(true);
      await removal;
      expect(visibleTitles(), [1, 2]);
      verifyNever(
        () => repo.removeItemFromList(
          listId: any(named: 'listId'),
          tmdbId: any(named: 'tmdbId'),
          mediaType: any(named: 'mediaType'),
        ),
      );
    });

    test('no Undo: removed from the server once the message closes', () async {
      when(
        () => repo.removeItemFromList(
          listId: 'a',
          tmdbId: 1,
          mediaType: MediaKind.movie,
        ),
      ).thenAnswer((_) async {});

      await remove(Future.value(false));

      expect(visibleTitles(), [2]);
      verify(
        () => repo.removeItemFromList(
          listId: 'a',
          tmdbId: 1,
          mediaType: MediaKind.movie,
        ),
      ).called(1);
    });

    test('a failed removal brings it back and rethrows', () async {
      when(
        () => repo.removeItemFromList(
          listId: 'a',
          tmdbId: 1,
          mediaType: MediaKind.movie,
        ),
      ).thenThrow(const NetworkFailure('offline'));

      await expectLater(
        remove(Future.value(false)),
        throwsA(isA<NetworkFailure>()),
      );
      expect(visibleTitles(), [1, 2]);
    });
  });

  // REV-257: an empty list can stay pinned; Home skips its row.
  test('Home shows only pinned lists that have titles', () async {
    final item = UserListItem(
      listId: 'a',
      tmdbId: 1,
      mediaType: MediaKind.movie,
      addedAt: DateTime(2026),
    );
    container.listen(pinnedHomeListsProvider, (_, _) {});
    dbLists.add([
      _list('a', items: [item]),
      _list('b'),
      _list('c', items: [item]),
    ]);
    await pumpEventQueue();

    final shown = container.read(pinnedHomeListsProvider).value!;
    expect(shown.map((l) => l.id), ['a']);
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

  // A search or Explore card has only part of a title's details: saving it
  // would blank the runtime and genres in the cache everyone shares.
  group('adding a title from a card', () {
    final card = MediaItem(
      tmdbId: 5915,
      mediaType: MediaKind.movie,
      titleIt: 'Into the Wild',
      updatedAt: DateTime(2026),
    );

    setUp(() {
      when(
        () => repo.addItemToList(
          listId: any(named: 'listId'),
          tmdbId: any(named: 'tmdbId'),
          mediaType: any(named: 'mediaType'),
        ),
      ).thenAnswer((_) async {});
    });

    test('to a custom list never saves the card over the title', () async {
      await container
          .read(userListsProvider.notifier)
          .addItemToCustomList('a', card);

      verifyNever(() => cache.saveMediaItem(any()));
      verify(() => cache.getMediaItem(5915, MediaKind.movie)).called(1);
      verify(
        () => repo.addItemToList(
          listId: 'a',
          tmdbId: 5915,
          mediaType: MediaKind.movie,
        ),
      ).called(1);
    });

    test('to the watchlist never saves the card over the title', () async {
      when(
        () => repo.watchUserLists(any()),
      ).thenAnswer((_) => Stream.value([_list('w', type: ListType.watchlist)]));

      await container.read(userListsProvider.notifier).toggleWatchlist(card);

      verifyNever(() => cache.saveMediaItem(any()));
      verify(() => cache.getMediaItem(5915, MediaKind.movie)).called(1);
    });

    test('a failed lookup still adds the title', () async {
      when(
        () => cache.getMediaItem(any(), any()),
      ).thenThrow(const NetworkFailure('offline'));

      await container
          .read(userListsProvider.notifier)
          .addItemToCustomList('a', card);

      verify(
        () => repo.addItemToList(
          listId: 'a',
          tmdbId: 5915,
          mediaType: MediaKind.movie,
        ),
      ).called(1);
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
      container.listen(droppedListProvider, (_, _) {});
      await container.read(droppedListProvider.future);
      when(
        () => progressRepo.restoreToContinueWatching('user-a', 7, 'movie'),
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
