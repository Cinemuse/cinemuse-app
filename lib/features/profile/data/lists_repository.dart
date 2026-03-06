import 'dart:convert';
import 'package:cinemuse_app/core/error/supabase_extensions.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart';
import 'package:cinemuse_app/core/data/database.dart' hide MediaItem;

class ListsRepository {
  final SupabaseClient _client;
  final AppDatabase _db;

  ListsRepository(this._client, this._db);

  /// Fetch all lists for a user, including their items.
  Future<List<UserList>> getUserLists(String userId) async {
    // Sync then rely on watchUserLists for reactive UI
    await syncUserLists(userId);
    
    // Fallback fetch from remote if needed for direct await (rarely used now)
    
    final response = await _client
        .from('lists')
        .select('*, list_items(*)')
        .eq('user_id', userId)
        .order('sort_order', ascending: true)
        .withErrorHandling();
    
    final data = response as List<dynamic>;
    return data.map((json) => UserList.fromJson(json)).toList();
  }

  /// Watch user lists locally
  Stream<List<UserList>> watchUserLists(String userId) {
    return _db.watchUserLists(userId).asyncMap((dbLists) async {
      final userLists = <UserList>[];
      for (final dbList in dbLists) {
        final dbItems = await (_db.select(_db.cachedListItems)..where((t) => t.listId.equals(dbList.id))).get();
        final items = dbItems.map((i) => UserListItem(
          listId: i.listId,
          tmdbId: i.mediaTmdbId,
          mediaType: MediaItem.fromString(i.mediaType),
          sortOrder: i.sortOrder,
          meta: i.meta != null ? jsonDecode(i.meta!) as Map<String, dynamic> : {},
          addedAt: i.addedAt,
        )).toList();

        userLists.add(UserList(
          id: dbList.id,
          userId: dbList.userId,
          name: dbList.name,
          type: ListType.values.firstWhere((e) => e.name == dbList.type),
          description: dbList.description,
          sortOrder: dbList.sortOrder,
          items: items,
          createdAt: dbList.createdAt,
        ));
      }
      return userLists;
    });
  }

  /// Synchronize lists and items with Supabase
  Future<void> syncUserLists(String userId) async {
    try {
      final response = await _client
          .from('lists')
          .select('*, list_items(*)')
          .eq('user_id', userId)
          .withErrorHandling();

      final lists = (response as List).map((json) => CachedUserListsCompanion(
        id: Value(json['id'] as String),
        userId: Value(userId),
        name: Value(json['name'] as String),
        type: Value(json['type'] as String),
        description: Value(json['description'] as String?),
        sortOrder: Value(json['sort_order'] as int? ?? 0),
        createdAt: Value(DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String())),
      )).toList();

      final items = <CachedListItemsCompanion>[];
      for (final listJson in (response as List)) {
        final listId = listJson['id'] as String;
        final itemsJson = listJson['list_items'] as List? ?? [];
        for (final itemJson in itemsJson) {
          items.add(CachedListItemsCompanion(
            listId: Value(listId),
            mediaTmdbId: Value(itemJson['media_tmdb_id'] as int),
            mediaType: Value(itemJson['media_type'] as String),
            meta: Value(itemJson['meta'] != null ? jsonEncode(itemJson['meta']) : null),
            sortOrder: Value(itemJson['sort_order'] as int? ?? 0),
            addedAt: Value(DateTime.parse(itemJson['added_at'] as String? ?? DateTime.now().toIso8601String())),
          ));
        }
      }

      await _db.syncUserLists(userId, lists, items);
    } catch (e) {
      print('ListsRepository: Sync failed: $e');
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
    final response = await _client
        .from('lists')
        .insert({
          'user_id': userId,
          'name': name,
          'type': type.name,
          'description': description,
          'sort_order': sortOrder,
        })
        .select()
        .single()
        .withErrorHandling();
    
    final newList = UserList.fromJson(response);

    // Update Local
    await _db.upsertUserList(CachedUserListsCompanion(
      id: Value(newList.id),
      userId: Value(userId),
      name: Value(name),
      type: Value(type.name),
      description: Value(description),
      sortOrder: Value(sortOrder),
      createdAt: Value(newList.createdAt),
    ));

    return newList;
  }

  /// Add an item to a specific list.
  Future<void> addItemToList({
    required String listId,
    required int tmdbId,
    required String mediaType,
    required Map<String, dynamic> meta,
    int? sortOrder,
  }) async {
    final normalizedType = (mediaType == 'series' || mediaType == 'tv') ? 'tv' : mediaType;

    // Update Local
    await _db.upsertListItem(CachedListItemsCompanion(
      listId: Value(listId),
      mediaTmdbId: Value(tmdbId),
      mediaType: Value(normalizedType),
      meta: Value(jsonEncode(meta)),
      sortOrder: Value(sortOrder ?? 0),
      addedAt: Value(DateTime.now()),
    ));

    // Update Remote
    await _client.from('list_items').upsert({
      'list_id': listId,
      'media_tmdb_id': tmdbId,
      'media_type': normalizedType,
      'meta': meta,
      'sort_order': sortOrder ?? 0,
    }, onConflict: 'list_id,media_tmdb_id,media_type').withErrorHandling();
  }

  /// Remove an item from a list.
  Future<void> removeItemFromList({
    required String listId,
    required int tmdbId,
    required String mediaType,
  }) async {
    final normalizedType = (mediaType == 'series' || mediaType == 'tv') ? 'tv' : mediaType;

    // Update Local
    await _db.deleteListItem(listId, tmdbId, normalizedType);

    // Update Remote
    await _client
        .from('list_items')
        .delete()
        .eq('list_id', listId)
        .eq('media_tmdb_id', tmdbId)
        .eq('media_type', normalizedType)
        .withErrorHandling();
  }

  /// Delete a list.
  Future<void> deleteList(String listId) async {
    // Update Local
    await _db.deleteUserList(listId);
    
    // Update Remote
    await _client.from('lists').delete().eq('id', listId).withErrorHandling();
  }

  /// Update a list's basic info.
  Future<void> updateList({
    required String listId,
    String? name,
    String? description,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    
    if (updates.isEmpty) return;

    await _client
        .from('lists')
        .update(updates)
        .eq('id', listId)
        .withErrorHandling();
  }
}
