import 'dart:convert';
import 'package:cinemuse_app/core/error/supabase_extensions.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;
import 'package:drift/drift.dart';
import 'package:cinemuse_app/core/data/database.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class ListsRepository {
  final SupabaseClient _client;
  final AppDatabase _db;
  final MediaRepository _mediaRepo;

  ListsRepository(this._client, this._db, this._mediaRepo);

  /// Watch user lists locally
  Stream<List<UserList>> watchUserLists(String userId) {
    // Using a join ensures the stream triggers when either table changes
    final query =
        _db.select(_db.cachedUserLists).join([
            leftOuterJoin(
              _db.cachedListItems,
              _db.cachedListItems.listId.equalsExp(_db.cachedUserLists.id),
            ),
            leftOuterJoin(
              _db.cachedMediaItems,
              _db.cachedMediaItems.tmdbId.equalsExp(
                    _db.cachedListItems.tmdbId,
                  ) &
                  _db.cachedMediaItems.mediaType.equalsExp(
                    _db.cachedListItems.mediaType,
                  ),
            ),
          ])
          ..where(_db.cachedUserLists.userId.equals(userId))
          ..orderBy([OrderingTerm.asc(_db.cachedUserLists.sortOrder)]);

    return query.watch().asyncMap((rows) async {
      // Group items by list ID to reconstruct the UserList objects
      final listMap = <String, List<UserListItem>>{};
      final dbLists = <String, CachedUserList>{};

      for (final row in rows) {
        final list = row.readTable(_db.cachedUserLists);
        dbLists[list.id] = list;

        final item = row.readTableOrNull(_db.cachedListItems);
        if (item != null) {
          final mediaRow = row.readTableOrNull(_db.cachedMediaItems);
          MediaItem? mediaItem;
          if (mediaRow != null) {
            mediaItem = MediaItem(
              tmdbId: mediaRow.tmdbId,
              mediaType: MediaItem.fromString(mediaRow.mediaType),
              titleIt: mediaRow.titleIt,
              titleEn: mediaRow.titleEn,
              posterPath: mediaRow.posterPath,
              backdropPath: mediaRow.backdropPath,
              runtimeMinutes: mediaRow.runtimeMinutes,
              genres: mediaRow.genres != null
                  ? (jsonDecode(mediaRow.genres!) as List).cast<int>()
                  : null,
              castMembers: mediaRow.castMembers != null
                  ? (jsonDecode(mediaRow.castMembers!) as List).cast<int>()
                  : null,
              releaseDate: mediaRow.releaseDate,
              voteAverage: mediaRow.voteAverage,
              updatedAt: mediaRow.updatedAt,
            );
          }

          listMap
              .putIfAbsent(list.id, () => [])
              .add(
                UserListItem(
                  listId: item.listId,
                  tmdbId: item.tmdbId,
                  mediaType: MediaItem.fromString(item.mediaType),
                  sortOrder: item.sortOrder,
                  meta: item.meta != null
                      ? jsonDecode(item.meta!) as Map<String, dynamic>
                      : {},
                  addedAt: item.addedAt,
                  media: mediaItem,
                ),
              );
        }
      }

      return dbLists.values.map((dbList) {
        return UserList(
          id: dbList.id,
          userId: dbList.userId,
          name: dbList.name,
          type: ListType.fromDb(dbList.type),
          description: dbList.description,
          sortOrder: dbList.sortOrder,
          items: listMap[dbList.id] ?? [],
          createdAt: dbList.createdAt,
        );
      }).toList();
    });
  }

  /// Synchronize lists and items with Supabase
  Future<void> syncUserLists(String userId) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.isNotEmpty &&
          connectivity.first == ConnectivityResult.none) {
        return; // Don't attempt to sync if offline
      }

      final response = await _client
          .from('lists')
          .select('*, list_items(*)')
          .eq('user_id', userId)
          .withErrorHandling();

      final lists = (response as List)
          .map(
            (json) => CachedUserListsCompanion(
              id: Value(json['id'] as String),
              userId: Value(userId),
              name: Value(json['name'] as String),
              type: Value(json['type'] as String),
              description: Value(json['description'] as String?),
              sortOrder: Value(json['sort_order'] as int? ?? 0),
              createdAt: Value(
                DateTime.parse(
                  json['created_at'] as String? ??
                      DateTime.now().toIso8601String(),
                ),
              ),
            ),
          )
          .toList();

      final items = <CachedListItemsCompanion>[];
      for (final listJson in (response as List)) {
        final listId = listJson['id'] as String;
        final itemsJson = listJson['list_items'] as List? ?? [];
        for (final itemJson in itemsJson) {
          items.add(
            CachedListItemsCompanion(
              listId: Value(listId),
              tmdbId: Value(itemJson['tmdb_id'] as int),
              mediaType: Value(itemJson['media_type'] as String),
              sortOrder: Value(itemJson['sort_order'] as int? ?? 0),
              addedAt: Value(
                DateTime.parse(
                  itemJson['added_at'] as String? ??
                      DateTime.now().toIso8601String(),
                ),
              ),
            ),
          );
        }
      }

      await _db.syncUserLists(userId, lists, items);

      // Remote list items carry no title or poster: fill them in from
      // media_cache, or a second device shows "Unknown" (REV-88).
      await _mediaRepo.cacheMissingFromRemote(
        items
            .map(
              (i) => (
                id: i.tmdbId.value,
                type: MediaItem.fromString(i.mediaType.value),
              ),
            )
            .toList(),
      );
    } catch (e) {
      if (!e.toString().contains('Failed host lookup') &&
          !e.toString().contains('SocketException')) {
        debugPrint('ListsRepository: Sync failed: $e');
      }
    }
  }

  /// Create a new list (system or custom).
  Future<UserList> createList({
    required String userId,
    required String name,
    required ListType type,
    String? description,
    int sortOrder = 0,
  }) async {
    final tempId = const Uuid().v4();
    final now = DateTime.now().toUtc();

    // Optimistic Local Update
    await _db.upsertUserList(
      CachedUserListsCompanion(
        id: Value(tempId),
        userId: Value(userId),
        name: Value(name),
        type: Value(type.dbName),
        description: Value(description),
        sortOrder: Value(sortOrder),
        createdAt: Value(now),
      ),
    );

    try {
      final response = await _client
          .from('lists')
          .insert({
            'id': tempId,
            'user_id': userId,
            'name': name,
            'type': type.dbName,
            'description': description,
            'sort_order': sortOrder,
            'created_at': now.toIso8601String(),
          })
          .select()
          .single()
          .withErrorHandling();

      final newList = UserList.fromJson(response);

      // Re-upsert with authoritative server response (in case of slight changes or triggers)
      await _db.upsertUserList(
        CachedUserListsCompanion(
          id: Value(newList.id),
          userId: Value(newList.userId),
          name: Value(newList.name),
          type: Value(newList.type.dbName),
          description: Value(newList.description),
          sortOrder: Value(newList.sortOrder),
          createdAt: Value(newList.createdAt),
        ),
      );

      return newList;
    } catch (e) {
      // Revert optimistic insert on failure
      await _db.deleteUserList(tempId);
      rethrow;
    }
  }

  /// Add an item to a specific list.
  Future<void> addItemToList({
    required String listId,
    required int tmdbId,
    required MediaKind mediaType,
    required Map<String, dynamic> meta,
    int? sortOrder,
  }) async {
    // Update Local
    await _db.upsertListItem(
      CachedListItemsCompanion(
        listId: Value(listId),
        tmdbId: Value(tmdbId),
        mediaType: Value(mediaType.name),
        meta: Value(jsonEncode(meta)),
        sortOrder: Value(sortOrder ?? 0),
        addedAt: Value(DateTime.now()),
      ),
    );

    // Update Remote
    await _client.from('list_items').upsert({
      'list_id': listId,
      'tmdb_id': tmdbId,
      'media_type': mediaType.name,
      'sort_order': sortOrder ?? 0,
    }, onConflict: 'list_id,tmdb_id,media_type').withErrorHandling();
  }

  /// Remove an item from a list.
  Future<void> removeItemFromList({
    required String listId,
    required int tmdbId,
    required MediaKind mediaType,
  }) async {
    // Update Local
    await _db.deleteListItem(listId, tmdbId, mediaType.name);

    // Update Remote
    await _client
        .from('list_items')
        .delete()
        .eq('list_id', listId)
        .eq('tmdb_id', tmdbId)
        .eq('media_type', mediaType.name)
        .withErrorHandling();
  }

  /// Delete a list.
  Future<void> deleteList(String listId) async {
    // Update Local
    await _db.deleteUserList(listId);

    // Update Remote
    await _client.from('lists').delete().eq('id', listId).withErrorHandling();
  }

  Future<void> updateList({
    required String listId,
    String? name,
    String? description,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;

    if (updates.isEmpty) return;

    // 1. Optimistic Local Update
    final companion = CachedUserListsCompanion(
      id: Value(listId),
      name: name != null ? Value(name) : const Value.absent(),
      description: description != null
          ? Value(description)
          : const Value.absent(),
    );
    await (_db.update(
      _db.cachedUserLists,
    )..where((t) => t.id.equals(listId))).write(companion);

    // 2. Remote Sync
    await _client
        .from('lists')
        .update(updates)
        .eq('id', listId)
        .withErrorHandling();
  }
}
