import 'package:cinemuse_app/core/services/supabase_service.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ListsRepository {
  final SupabaseClient _client;

  ListsRepository(this._client);

  /// Fetch all lists for a user, including their items.
  Future<List<UserList>> getUserLists(String userId) async {
    try {
      final response = await _client
          .from('lists')
          .select('*, list_items(*)')
          .eq('user_id', userId)
          .order('sort_order', ascending: true);
      
      final data = response as List<dynamic>;
      return data.map((json) => UserList.fromJson(json)).toList();
    } catch (e) {
      return [];
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
        .single();
    
    return UserList.fromJson(response);
  }

  /// Add an item to a specific list.
  Future<void> addItemToList({
    required String listId,
    required int tmdbId,
    required String mediaType,
    required Map<String, dynamic> meta,
    int? sortOrder,
  }) async {
    // Normalizing type to 'tv' if it comes in as 'series' for consistency in DB
    final normalizedType = (mediaType == 'series' || mediaType == 'tv') ? 'tv' : mediaType;

    await _client.from('list_items').upsert({
      'list_id': listId,
      'media_tmdb_id': tmdbId,
      'media_type': normalizedType,
      'meta': meta,
      'sort_order': sortOrder ?? 0,
    }, onConflict: 'list_id,media_tmdb_id,media_type');
  }

  /// Remove an item from a list.
  Future<void> removeItemFromList({
    required String listId,
    required int tmdbId,
    required String mediaType,
  }) async {
    final typesToDelete = (mediaType == 'series' || mediaType == 'tv') ? ['series', 'tv'] : [mediaType];

    await _client
        .from('list_items')
        .delete()
        .eq('list_id', listId)
        .eq('media_tmdb_id', tmdbId)
        .filter('media_type', 'in', '(${typesToDelete.map((t) => '"$t"').join(',')})');
  }

  /// Delete a list.
  Future<void> deleteList(String listId) async {
    await _client.from('lists').delete().eq('id', listId);
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
        .eq('id', listId);
  }
}
