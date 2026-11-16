import 'dart:io';

import 'package:cinemuse_app/core/data/database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

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

    test('upsertMediaItem stores one row', () async {
      await database.upsertMediaItem(
        CachedMediaItemsCompanion.insert(
          tmdbId: 1,
          mediaType: 'movie',
          updatedAt: DateTime.now(),
        ),
      );

      final items = await database.select(database.cachedMediaItems).get();
      expect(items.length, 1);
    });
  });

  group('Watch History Tests', () {
    const userId = 'user-123';

    test('can upsert and watch history', () async {
      await database.upsertWatchHistory(
        LocalWatchHistoriesCompanion.insert(
          userId: userId,
          tmdbId: 1,
          mediaType: 'movie',
          status: 'watching',
          lastWatchedAt: DateTime.now(),
        ),
      );

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
      await database.upsertUserList(
        CachedUserListsCompanion.insert(
          id: listId,
          userId: userId,
          name: 'My Watchlist',
          type: 'watchlist',
        ),
      );

      final lists = await database.watchUserLists(userId).first;
      expect(lists.length, 1);
      expect(lists.first.name, 'My Watchlist');
    });

    test('can add and watch list items', () async {
      await database.upsertListItem(
        CachedListItemsCompanion.insert(
          listId: listId,
          tmdbId: 101,
          mediaType: 'movie',
        ),
      );

      final items = await (database.select(
        database.cachedListItems,
      )..where((t) => t.listId.equals(listId))).get();
      expect(items.length, 1);
      expect(items.first.tmdbId, 101);
    });

    test('syncUserLists removes old and adds new', () async {
      // Setup old list
      await database.upsertUserList(
        CachedUserListsCompanion.insert(
          id: 'old-list',
          userId: userId,
          name: 'Old',
          type: 'custom',
        ),
      );

      final newLists = [
        CachedUserListsCompanion.insert(
          id: 'new-list',
          userId: userId,
          name: 'New',
          type: 'custom',
        ),
      ];
      final newItems = [
        CachedListItemsCompanion.insert(
          listId: 'new-list',
          tmdbId: 202,
          mediaType: 'movie',
        ),
      ];

      await database.syncUserLists(userId, newLists, newItems);

      final lists = await database.watchUserLists(userId).first;
      expect(lists.length, 1);
      expect(lists.first.id, 'new-list');

      final items = await (database.select(
        database.cachedListItems,
      )..where((t) => t.listId.equals('new-list'))).get();
      expect(items.length, 1);
      expect(items.first.tmdbId, 202);
    });
  });

  group('Migrations', () {
    test('from version 5 keeps the titles, without the cast numbers', () async {
      final dir = await Directory.systemTemp.createTemp('cinemuse_db');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/app.sqlite');

      // A version 5 database: today's tables plus the old cast column.
      final fresh = AppDatabase(NativeDatabase(file));
      await fresh.select(fresh.cachedMediaItems).get();
      await fresh.close();
      final raw = sqlite3.open(file.path);
      raw.execute(
        'ALTER TABLE cached_media_items ADD COLUMN cast_members TEXT',
      );
      raw.execute(
        'INSERT INTO cached_media_items '
        '(tmdb_id, media_type, title_en, runtime_minutes, cast_members, '
        "updated_at) VALUES (1396, 'tv', 'Breaking Bad', 59, '[17419]', 0)",
      );
      raw.execute('PRAGMA user_version = 5');
      raw.dispose();

      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);
      final title = await upgraded.getMediaItem(1396, 'tv');
      final columns = await upgraded
          .customSelect('PRAGMA table_info(cached_media_items)')
          .map((row) => row.read<String>('name'))
          .get();

      expect(title?.titleEn, 'Breaking Bad');
      expect(title?.runtimeMinutes, 59);
      expect(columns, isNot(contains('cast_members')));
    });

    // An older build opening the file writes its own lower version back, so
    // the steps run again on a file they already changed.
    test('a lower version whose cast column is already gone still opens, '
        'at the current version', () async {
      final dir = await Directory.systemTemp.createTemp('cinemuse_db');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/app.sqlite');

      final fresh = AppDatabase(NativeDatabase(file));
      await fresh.upsertMediaItem(
        CachedMediaItemsCompanion.insert(
          tmdbId: 1396,
          mediaType: 'tv',
          titleEn: const Value('Breaking Bad'),
          updatedAt: DateTime.utc(2026, 11, 11),
        ),
      );
      await fresh.close();
      final raw = sqlite3.open(file.path);
      raw.execute('PRAGMA user_version = 4');
      raw.dispose();

      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);
      final title = await upgraded.getMediaItem(1396, 'tv');
      final version = await upgraded
          .customSelect('PRAGMA user_version')
          .map((row) => row.read<int>('user_version'))
          .getSingle();

      expect(title?.titleEn, 'Breaking Bad');
      expect(version, upgraded.schemaVersion);
    });

    // REV-268: version 4 drops the list items' `meta` column.
    test('from version 3 keeps the list items, without meta', () async {
      final dir = await Directory.systemTemp.createTemp('cinemuse_db');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/app.sqlite');

      // A version 3 database: today's tables plus the old `meta` column.
      final fresh = AppDatabase(NativeDatabase(file));
      await fresh.select(fresh.cachedListItems).get();
      await fresh.close();
      final raw = sqlite3.open(file.path);
      raw.execute(
        'ALTER TABLE cached_media_items ADD COLUMN cast_members TEXT',
      );
      raw.execute('ALTER TABLE cached_list_items ADD COLUMN meta TEXT');
      raw.execute(
        'INSERT INTO cached_list_items '
        '(list_id, tmdb_id, media_type, meta, sort_order, added_at) '
        "VALUES ('list-1', 7, 'movie', '{}', 0, 0)",
      );
      raw.execute('PRAGMA user_version = 3');
      raw.dispose();

      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);
      final items = await upgraded.select(upgraded.cachedListItems).get();
      final columns = await upgraded
          .customSelect('PRAGMA table_info(cached_list_items)')
          .map((row) => row.read<String>('name'))
          .get();

      expect(items.single.tmdbId, 7);
      expect(columns, isNot(contains('meta')));
    });

    test('from version 4 empties the anime copy and drops the Kitsu table, '
        'so the new list downloads', () async {
      final dir = await Directory.systemTemp.createTemp('cinemuse_db');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/app.sqlite');

      // A version 4 database: the old anime tables, one line in each.
      final fresh = AppDatabase(NativeDatabase(file));
      await fresh.select(fresh.cachedListItems).get();
      await fresh.close();
      final raw = sqlite3.open(file.path);
      raw.execute(
        'ALTER TABLE cached_media_items ADD COLUMN cast_members TEXT',
      );
      raw.execute('DROP TABLE anime_external_mappings');
      raw.execute(
        'CREATE TABLE anime_external_mappings (anilist_id INTEGER NOT NULL '
        'PRIMARY KEY, anidb_id INTEGER, tmdb_show_id INTEGER, '
        'tmdb_movie_id INTEGER, tvdb_id INTEGER, mappings_data TEXT)',
      );
      raw.execute(
        'INSERT INTO anime_external_mappings (anilist_id, tmdb_show_id, '
        "mappings_data) VALUES (142853, 105009, '{\"s1\":\"e25-e37\"}')",
      );
      raw.execute(
        'CREATE TABLE anime_kitsu_mappings (anilist_id INTEGER NOT NULL '
        'PRIMARY KEY, kitsu_id TEXT NOT NULL, episode_count INTEGER, '
        'updated_at INTEGER NOT NULL)',
      );
      raw.execute(
        "INSERT INTO anime_kitsu_mappings VALUES (142853, '45607', 13, 0)",
      );
      raw.execute('PRAGMA user_version = 4');
      raw.dispose();

      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);
      final count = await upgraded.getAnimeExternalMappingsCount();
      final tables = await upgraded
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((row) => row.read<String>('name'))
          .get();
      await upgraded.replaceAnimeExternalMappings([
        const AnimeExternalMappingsCompanion(
          anilistId: Value(142853),
          kitsuId: Value(45607),
          tmdbShowId: Value(105009),
          tmdbEpisodes: Value(
            '[{"season":1,"first":25,"last":37,"anime_first":1}]',
          ),
        ),
      ]);

      expect(count, 0);
      expect(tables, isNot(contains('anime_kitsu_mappings')));
      expect(
        (await upgraded.getAnimeMappingsByTmdbShow(105009)).single.kitsuId,
        45607,
      );
    });
  });
}
