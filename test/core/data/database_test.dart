import 'package:cinemuse_app/core/data/database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('Media Cache Tests', () {
    test('can upsert and retrieve a media item', () async {
      final item = CachedMediaItemsCompanion.insert(
        tmdbId: 1,
        mediaType: 'movie',
        titleEn: Value('Inception'),
        updatedAt: DateTime.now(),
      );

      await database.upsertMediaItem(item);

      final retrieved = await database.getMediaItem(1, 'movie');
      expect(retrieved?.titleEn, 'Inception');
    });

    test('can retrieve total count', () async {
      await database.upsertMediaItem(CachedMediaItemsCompanion.insert(
        tmdbId: 1,
        mediaType: 'movie',
        updatedAt: DateTime.now(),
      ));

      final items = await database.getTotalCount();
      expect(items, 1);
    });
  });

  group('Watch History Tests', () {
    const userId = 'user-123';

    test('can upsert and watch history', () async {
      await database.upsertWatchHistory(LocalWatchHistoriesCompanion.insert(
        userId: userId,
        tmdbId: 1,
        mediaType: 'movie',
        status: 'watching',
        lastWatchedAt: DateTime.now(),
      ));

      final history = await database.getWatchHistory(userId);
      expect(history.length, 1);
      expect(history.first.tmdbId, 1);
    });

    test('can sync whole history', () async {
      final entries = [
        LocalWatchHistoriesCompanion.insert(
          userId: userId,
          tmdbId: 1,
          mediaType: 'movie',
          status: 'watching',
          lastWatchedAt: DateTime.now(),
        ),
        LocalWatchHistoriesCompanion.insert(
          userId: userId,
          tmdbId: 2,
          mediaType: 'movie',
          status: 'watching',
          lastWatchedAt: DateTime.now(),
        ),
      ];

      await database.syncWatchHistory(userId, entries);
      
      final history = await database.getWatchHistory(userId);
      expect(history.length, 2);
    });
  });

  group('User Lists Tests', () {
    const userId = 'user-123';
    const listId = 'list-456';

    test('can upsert and retrieve user lists', () async {
      await database.upsertUserList(CachedUserListsCompanion.insert(
        id: listId,
        userId: userId,
        name: 'My Watchlist',
        type: 'watchlist',
      ));

      final lists = await database.watchUserLists(userId).first;
      expect(lists.length, 1);
      expect(lists.first.name, 'My Watchlist');
    });

    test('can add and watch list items', () async {
      await database.upsertListItem(CachedListItemsCompanion.insert(
        listId: listId,
        mediaTmdbId: 101,
        mediaType: 'movie',
      ));

      final items = await database.watchListItems(listId).first;
      expect(items.length, 1);
      expect(items.first.mediaTmdbId, 101);
    });

    test('syncUserLists removes old and adds new', () async {
      // Setup old list
      await database.upsertUserList(CachedUserListsCompanion.insert(
        id: 'old-list',
        userId: userId,
        name: 'Old',
        type: 'custom',
      ));

      final newLists = [
        CachedUserListsCompanion.insert(
          id: 'new-list',
          userId: userId,
          name: 'New',
          type: 'custom',
        )
      ];
      final newItems = [
        CachedListItemsCompanion.insert(
          listId: 'new-list',
          mediaTmdbId: 202,
          mediaType: 'movie',
        )
      ];

      await database.syncUserLists(userId, newLists, newItems);

      final lists = await database.watchUserLists(userId).first;
      expect(lists.length, 1);
      expect(lists.first.id, 'new-list');

      final items = await database.watchListItems('new-list').first;
      expect(items.length, 1);
      expect(items.first.mediaTmdbId, 202);
    });
  });
}
