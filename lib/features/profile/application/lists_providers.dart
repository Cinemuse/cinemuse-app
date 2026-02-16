import 'package:cinemuse_app/core/services/supabase_service.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/profile/data/lists_repository.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final listsRepositoryProvider = Provider<ListsRepository>((ref) {
  return ListsRepository(supabase);
});

/// A notifier that manages all user lists (Watchlist, Favorites, and Custom).
/// It provides a centralized way to toggle items and refresh the UI globally.
class UserListsNotifier extends AsyncNotifier<List<UserList>> {
  @override
  Future<List<UserList>> build() async {
    final userAsync = ref.watch(authProvider);
    final user = userAsync.value;
    
    if (user == null) return [];
    
    final repo = ref.watch(listsRepositoryProvider);
    return repo.getUserLists(user.id);
  }

  /// Toggles an item in a system list (Watchlist or Favorites).
  Future<void> toggleSystemList(MediaItem media, ListType type) async {
    final user = ref.read(authProvider).value;
    if (user == null) return;

    final lists = await future; // Ensure we have latest data
    
    // Find the specific list of this type
    var targetList = lists.firstWhere(
      (l) => l.type == type,
      orElse: () => throw Exception('System list $type not found. Ensure it exists in DB.'),
    );

    // Find if the item exists in the list (checking both 'tv' and 'series' for series)
    final isTV = media.mediaType == MediaKind.tv;
    final exists = targetList.items.any((item) {
      if (item.tmdbId != media.tmdbId) return false;
      if (isTV) return item.mediaType == MediaKind.tv;
      return item.mediaType == media.mediaType;
    });

    final repo = ref.read(listsRepositoryProvider);

    if (exists) {
      await repo.removeItemFromList(
        listId: targetList.id,
        tmdbId: media.tmdbId,
        mediaType: media.mediaType.name,
      );
    } else {
      // Naturally cache the item when it's being added to a system list
      ref.read(watchHistoryRepositoryProvider).ensureMediaCached(media)
          .catchError((e) => print('Background caching failed: $e'));

      await repo.addItemToList(
        listId: targetList.id,
        tmdbId: media.tmdbId,
        mediaType: media.mediaType.name,
        meta: {
          'title': media.title,
          'poster_path': media.posterPath,
          'backdrop_path': media.backdropPath,
          'rating': media.voteAverage,
          'year': media.releaseDate?.year,
        },
      );
    }
    
    // Refresh the state
    ref.invalidateSelf();
  }

  Future<void> toggleWatchlist(MediaItem media) async {
    await toggleSystemList(media, ListType.watchlist);
  }

  Future<void> toggleFavorite(MediaItem media) async {
    await toggleSystemList(media, ListType.favorites);
  }

  Future<void> createCustomList(String name, {String? description}) async {
    final user = ref.read(authProvider).value;
    if (user == null) return;

    final repo = ref.read(listsRepositoryProvider);
    await repo.createList(
      userId: user.id,
      name: name,
      type: ListType.custom,
      description: description,
    );
    
    ref.invalidateSelf();
  }

  Future<void> updateList(String listId, String name, String? description) async {
    final repo = ref.read(listsRepositoryProvider);
    await repo.updateList(
      listId: listId,
      name: name,
      description: description,
    );
    ref.invalidateSelf();
  }

  Future<void> addItemToCustomList(String listId, MediaItem media) async {
    final repo = ref.read(listsRepositoryProvider);

    // Naturally cache the item when it's being added to a custom list
    ref.read(watchHistoryRepositoryProvider).ensureMediaCached(media)
        .catchError((e) => print('Background caching failed: $e'));

    await repo.addItemToList(
      listId: listId,
      tmdbId: media.tmdbId,
      mediaType: media.mediaType.name,
      meta: {
        'title': media.title,
        'poster_path': media.posterPath,
        'backdrop_path': media.backdropPath,
        'rating': media.voteAverage,
        'year': media.releaseDate?.year,
      },
    );
    ref.invalidateSelf();
  }

  /// Helper to check if a specific item is in the Watchlist.
  bool isInWatchlist(int tmdbId, MediaKind mediaType) {
    final lists = state.value ?? [];
    final watchlist = lists.where((l) => l.type == ListType.watchlist).firstOrNull;
    if (watchlist == null) return false;
    return watchlist.items.any((i) => i.tmdbId == tmdbId && i.mediaType == mediaType);
  }

  /// Helper to check if a specific item is in Favorites.
  bool isFavorite(int tmdbId, MediaKind mediaType) {
    final lists = state.value ?? [];
    final favorites = lists.where((l) => l.type == ListType.favorites).firstOrNull;
    if (favorites == null) return false;
    return favorites.items.any((i) => i.tmdbId == tmdbId && i.mediaType == mediaType);
  }
}

final userListsProvider = AsyncNotifierProvider<UserListsNotifier, List<UserList>>(() {
  return UserListsNotifier();
});
