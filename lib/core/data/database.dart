import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database.g.dart';

class CachedMediaItems extends Table {
  IntColumn get tmdbId => integer()();
  TextColumn get mediaType => text()(); // 'movie' or 'tv'
  TextColumn get titleIt => text().nullable()();
  TextColumn get titleEn => text().nullable()();
  TextColumn get posterPath => text().nullable()();
  TextColumn get backdropPath => text().nullable()();
  IntColumn get runtimeMinutes => integer().nullable()();
  TextColumn get genres => text().nullable()(); // JSON string
  TextColumn get castMembers => text().nullable()(); // JSON string
  DateTimeColumn get releaseDate => dateTime().nullable()();
  RealColumn get voteAverage => real().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {tmdbId, mediaType};
}

class LocalWatchHistories extends Table {
  TextColumn get userId => text()();
  IntColumn get tmdbId => integer()();
  TextColumn get mediaType => text()();
  IntColumn get season => integer().withDefault(const Constant(0))();
  IntColumn get episode => integer().withDefault(const Constant(0))();
  TextColumn get status => text()();
  IntColumn get progressSeconds => integer().withDefault(const Constant(0))();
  IntColumn get totalDuration => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastWatchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {userId, tmdbId, mediaType, season, episode};
}

class CachedUserLists extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // 'system' or 'custom'
  TextColumn get description => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class CachedListItems extends Table {
  TextColumn get listId => text()();
  IntColumn get mediaTmdbId => integer()();
  TextColumn get mediaType => text()();
  TextColumn get meta => text().nullable()(); // JSON string
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {listId, mediaTmdbId, mediaType};
}

class AnimeExternalMappings extends Table {
  IntColumn get anilistId => integer()();
  IntColumn get anidbId => integer().nullable()();
  IntColumn get tmdbShowId => integer().nullable()();
  IntColumn get tmdbMovieId => integer().nullable()();
  IntColumn get tvdbId => integer().nullable()();
  TextColumn get mappingsData => text().nullable()(); // JSON string for tmdb_mappings or tvdb_mappings

  @override
  Set<Column> get primaryKey => {anilistId};
}

class AnimeKitsuMappings extends Table {
  IntColumn get anilistId => integer()();
  TextColumn get kitsuId => text()();
  IntColumn get episodeCount => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {anilistId};
}

class CachedProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get username => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get preferences => text().nullable()(); // JSON string
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  CachedMediaItems,
  LocalWatchHistories,
  CachedUserLists,
  CachedListItems,
  AnimeExternalMappings,
  AnimeKitsuMappings,
  CachedProfiles,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        beforeOpen: (details) async {
          // Safety: If database exists and version is different, 
          // we might want to wipe it during this dev reset phase.
          // For now, we trust the user to clear app data if needed,
          // but we can add a check here if requested.
        },
      );

  // --- Anime Mappings ---

  Future<void> replaceAnimeExternalMappings(List<AnimeExternalMappingsCompanion> mappings) async {
    await transaction(() async {
      await delete(animeExternalMappings).go();
      await batch((batch) {
        batch.insertAll(animeExternalMappings, mappings);
      });
    });
  }

  Future<List<AnimeExternalMapping>> getAnimeMappingsByTmdbShow(int tmdbShowId) {
    return (select(animeExternalMappings)..where((t) => t.tmdbShowId.equals(tmdbShowId))).get();
  }

  Future<List<AnimeExternalMapping>> getAnimeMappingsByTmdbMovie(int tmdbMovieId) {
    return (select(animeExternalMappings)..where((t) => t.tmdbMovieId.equals(tmdbMovieId))).get();
  }

  Future<void> upsertKitsuMapping(AnimeKitsuMappingsCompanion mapping) {
    return into(animeKitsuMappings).insertOnConflictUpdate(mapping);
  }

  Future<AnimeKitsuMapping?> getKitsuMapping(int anilistId) {
    return (select(animeKitsuMappings)..where((t) => t.anilistId.equals(anilistId))).getSingleOrNull();
  }

  Future<int> getAnimeExternalMappingsCount() async {
    final countExp = animeExternalMappings.anilistId.count();
    final query = selectOnly(animeExternalMappings)..addColumns([countExp]);
    final result = await query.map((row) => row.read(countExp)).getSingle();
    return result ?? 0;
  }

  Future<int> getAnimeMappingsMissingAnidbCount() async {
    final countExp = animeExternalMappings.anilistId.count();
    final query = selectOnly(animeExternalMappings)
      ..addColumns([countExp])
      ..where(animeExternalMappings.anidbId.isNull());
    final result = await query.map((row) => row.read(countExp)).getSingle();
    return result ?? 0;
  }

  // Helper to upsert a media item
  Future<void> upsertMediaItem(CachedMediaItemsCompanion item) async {
    await into(cachedMediaItems).insertOnConflictUpdate(item);
  }

  // Get a single media item
  Future<CachedMediaItem?> getMediaItem(int tmdbId, String mediaType) {
    return (select(cachedMediaItems)
          ..where((t) => t.tmdbId.equals(tmdbId) & t.mediaType.equals(mediaType)))
        .getSingleOrNull();
  }

  // Get multiple media items in bulk for optimization
  Future<List<CachedMediaItem>> getMediaItems(List<({int id, String type})> filters) {
    if (filters.isEmpty) return Future.value([]);
    
    return (select(cachedMediaItems)..where((t) {
      Expression<bool> predicate = const Constant(false);
      for (final filter in filters) {
        predicate = predicate | (t.tmdbId.equals(filter.id) & t.mediaType.equals(filter.type));
      }
      return predicate;
    })).get();
  }

  // Get all watch history for a user
  Future<List<LocalWatchHistory>> getWatchHistory(String userId) {
    return (select(localWatchHistories)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm(expression: t.lastWatchedAt, mode: OrderingMode.desc)]))
        .get();
  }

  // Upsert watch history entry
  Future<void> upsertWatchHistory(LocalWatchHistoriesCompanion entry) {
    return into(localWatchHistories).insertOnConflictUpdate(entry);
  }

  // Sync whole watch history
  Future<void> syncWatchHistory(String userId, List<LocalWatchHistoriesCompanion> entries) async {
    await batch((batch) {
      batch.deleteWhere(localWatchHistories, (t) => t.userId.equals(userId));
      batch.insertAll(localWatchHistories, entries);
    });
  }

  // Watch watch history locally
  Stream<List<LocalWatchHistory>> watchWatchHistory(String userId) {
    return (select(localWatchHistories)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm(expression: t.lastWatchedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  /// Joint stream for watch history and media cache to ensure reactivity to both tables.
  Stream<List<TypedResult>> watchWatchHistoryWithMedia(String userId) {
    final query = select(localWatchHistories).join([
      leftOuterJoin(
        cachedMediaItems, 
        cachedMediaItems.tmdbId.equalsExp(localWatchHistories.tmdbId) & 
        cachedMediaItems.mediaType.equalsExp(localWatchHistories.mediaType)
      ),
    ])
      ..where(localWatchHistories.userId.equals(userId))
      ..orderBy([OrderingTerm(expression: localWatchHistories.lastWatchedAt, mode: OrderingMode.desc)]);
      
    return query.watch();
  }

  // --- User Lists ---

  Future<void> syncUserLists(String userId, List<CachedUserListsCompanion> lists, List<CachedListItemsCompanion> items) async {
    await transaction(() async {
      // Find all existing list IDs for this user to manually delete their items
      final userListIds = await (selectOnly(cachedUserLists)
            ..addColumns([cachedUserLists.id])
            ..where(cachedUserLists.userId.equals(userId)))
          .map((row) => row.read(cachedUserLists.id)!)
          .get();

      // Delete old list items
      if (userListIds.isNotEmpty) {
        await (delete(cachedListItems)..where((t) => t.listId.isIn(userListIds))).go();
      }

      // Delete old lists
      await (delete(cachedUserLists)..where((t) => t.userId.equals(userId))).go();

      // Batch insert the freshly synced lists and items
      await batch((batch) {
        batch.insertAll(cachedUserLists, lists, mode: InsertMode.insertOrReplace);
        batch.insertAll(cachedListItems, items, mode: InsertMode.insertOrReplace);
      });
    });
  }

  Stream<List<CachedUserList>> watchUserLists(String userId) {
    return (select(cachedUserLists)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .watch();
  }

  Stream<List<CachedListItem>> watchListItems(String listId) {
    return (select(cachedListItems)
          ..where((t) => t.listId.equals(listId))
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .watch();
  }

  Future<void> upsertUserList(CachedUserListsCompanion list) async {
    await into(cachedUserLists).insertOnConflictUpdate(list);
  }

  Future<void> deleteUserList(String listId) async {
    await (delete(cachedUserLists)..where((t) => t.id.equals(listId))).go();
  }

  Future<void> upsertListItem(CachedListItemsCompanion item) async {
    await into(cachedListItems).insertOnConflictUpdate(item);
  }

  Future<void> deleteListItem(String listId, int tmdbId, String mediaType) async {
    await (delete(cachedListItems)
          ..where((t) => t.listId.equals(listId) & t.mediaTmdbId.equals(tmdbId) & t.mediaType.equals(mediaType)))
        .go();
  }

  // --- Profiles & Settings ---

  Future<void> upsertProfile(CachedProfilesCompanion profile) {
    return into(cachedProfiles).insertOnConflictUpdate(profile);
  }

  Future<CachedProfile?> getCachedProfile(String id) {
    return (select(cachedProfiles)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // --- Cleanup ---

  // Get total count of cached items
  Future<int> getTotalCount() async {
    final countExp = cachedMediaItems.tmdbId.count();
    final query = selectOnly(cachedMediaItems)..addColumns([countExp]);
    final result = await query.map((row) => row.read(countExp)).getSingle();
    return result ?? 0;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'cinemuse.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

@Riverpod(keepAlive: true)
AppDatabase appDatabase(AppDatabaseRef ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
}
