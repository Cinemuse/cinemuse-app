import 'dart:async';
import 'package:cinemuse_app/features/media/data/watch_progress_repository.dart';

import 'package:flutter/foundation.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/profile/application/pinned_list_ids_provider.dart';
import 'package:cinemuse_app/features/profile/data/lists_repository.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final listsRepositoryProvider = Provider<ListsRepository>((ref) {
  return ListsRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(appDatabaseProvider),
    ref.watch(mediaRepositoryProvider),
  );
});

/// A notifier that manages all user lists (Watchlist, Favorites, and Custom).
/// It now uses a stream from the local database for offline-first responsiveness.
class UserListsNotifier extends StreamNotifier<List<UserList>> {
  // Lists deleted while the undo snackbar is still open: hidden from every
  // database update, so a pull-to-refresh can't bring them back.
  final _pendingDeletes = <String>{};
  // Titles taken out of a list while the undo snackbar is open, hidden the
  // same way.
  final _pendingRemovals = <({String listId, int tmdbId, MediaKind type})>{};
  List<UserList> _latestLists = const [];

  List<UserList> _visible(List<UserList> lists) => [
    for (final list in lists)
      if (!_pendingDeletes.contains(list.id)) _withoutPendingRemovals(list),
  ];

  UserList _withoutPendingRemovals(UserList list) {
    bool isPending(UserListItem i) => _pendingRemovals.contains((
      listId: list.id,
      tmdbId: i.tmdbId,
      type: i.mediaType,
    ));
    if (!list.items.any(isPending)) return list;
    return list.withItems(list.items.where((i) => !isPending(i)).toList());
  }

  @override
  Stream<List<UserList>> build() {
    final user = ref.watch(authProvider).asData?.value;
    if (user == null) return Stream.value([]);

    final repo = ref.watch(listsRepositoryProvider);

    // Background sync
    repo
        .syncUserLists(user.id)
        .catchError((e) => debugPrint('UserListsNotifier: Sync failed: $e'));

    return repo.watchUserLists(user.id).map((lists) {
      _latestLists = lists;
      return _visible(lists);
    });
  }

  /// Toggles an item in a system list (Watchlist or Favorites).
  /// Throws a [NotFoundFailure] if the list is still missing after a sync.
  Future<void> toggleSystemList(MediaItem media, ListType type) async {
    final repo = ref.read(listsRepositoryProvider);
    UserList? findList(List<UserList> lists) =>
        lists.where((l) => l.type == type).firstOrNull;

    var targetList = findList(state.value ?? const []);
    if (targetList == null) {
      // Right after a fresh install the first sync may still be running.
      final user = ref.read(authProvider).value;
      if (user != null) {
        await repo.syncUserLists(user.id);
        targetList = findList(await repo.watchUserLists(user.id).first);
      }
    }
    if (targetList == null) {
      throw NotFoundFailure('System list ${type.name} not found');
    }

    final exists = targetList.items.any(
      (item) =>
          item.tmdbId == media.tmdbId && item.mediaType == media.mediaType,
    );

    if (exists) {
      await repo.removeItemFromList(
        listId: targetList.id,
        tmdbId: media.tmdbId,
        mediaType: media.mediaType,
      );
    } else {
      await _cacheTitle(media);

      await repo.addItemToList(
        listId: targetList.id,
        tmdbId: media.tmdbId,
        mediaType: media.mediaType,
      );
    }
    // No need to invalidateSelf(), the repository updates the local Drift DB
    // which automatically triggers a new event in our stream.
  }

  Future<void> toggleWatchlist(MediaItem media) async {
    await toggleSystemList(media, ListType.watchlist);
  }

  /// Takes [media] out of the Watchlist unless [undone] completes with true,
  /// like [removeItemWithUndo]. Throws a [NotFoundFailure] with no Watchlist.
  Future<void> removeFromWatchlistWithUndo(
    MediaItem media, {
    required Future<bool> undone,
  }) async {
    final watchlist = (state.value ?? const <UserList>[])
        .where((l) => l.type == ListType.watchlist)
        .firstOrNull;
    if (watchlist == null) {
      throw const NotFoundFailure('System list watchlist not found');
    }
    await removeItemWithUndo(
      watchlist.id,
      media.tmdbId,
      media.mediaType,
      undone: undone,
    );
  }

  Future<void> toggleFavorite(MediaItem media) async {
    await toggleSystemList(media, ListType.favorites);
  }

  /// Adds a title picked in a list's search: a custom list adds it, the
  /// Watchlist / Favorites add it only if it isn't there yet.
  Future<void> addFromSearch(UserList list, MediaItem media) async {
    switch (list.type) {
      case ListType.custom:
        await addItemToCustomList(list.id, media);
      case ListType.watchlist || ListType.favorites:
        if (!_isInList(list.type, media.tmdbId, media.mediaType)) {
          await toggleSystemList(media, list.type);
        }
      default:
        break;
    }
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
  }

  Future<void> updateList(
    String listId,
    String name,
    String? description,
  ) async {
    final repo = ref.read(listsRepositoryProvider);
    await repo.updateList(listId: listId, name: name, description: description);
  }

  Future<void> addItemToCustomList(String listId, MediaItem media) async {
    final repo = ref.read(listsRepositoryProvider);

    await _cacheTitle(media);

    await repo.addItemToList(
      listId: listId,
      tmdbId: media.tmdbId,
      mediaType: media.mediaType,
    );
  }

  /// Makes sure the title cache has the full details of a title joining a list.
  /// [media] may come from a search or Explore card, which has only part of
  /// them, so it is never saved itself: that would blank the rest in the cache
  /// everyone shares.
  Future<void> _cacheTitle(MediaItem media) async {
    try {
      await ref
          .read(mediaRepositoryProvider)
          .getMediaItem(media.tmdbId, media.mediaType);
    } catch (e, st) {
      // Safe to go on: the list item still saves; only its cached details
      // are missing until the title is opened.
      AppLogger.warn(
        'UserListsNotifier',
        'Caching the title failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> removeItemFromList(
    String listId,
    int tmdbId,
    MediaKind mediaType,
  ) async {
    final repo = ref.read(listsRepositoryProvider);
    await repo.removeItemFromList(
      listId: listId,
      tmdbId: tmdbId,
      mediaType: mediaType,
    );
  }

  /// Hides the title at once and removes it unless [undone] completes with
  /// true; like [deleteWithUndo], it comes back on undo or on failure, and
  /// the error is rethrown.
  Future<void> removeItemWithUndo(
    String listId,
    int tmdbId,
    MediaKind mediaType, {
    required Future<bool> undone,
  }) async {
    final key = (listId: listId, tmdbId: tmdbId, type: mediaType);
    _pendingRemovals.add(key);
    state = AsyncData(_visible(_latestLists));
    try {
      if (await undone) return;
      await removeItemFromList(listId, tmdbId, mediaType);
      // Gone even if the database update hasn't arrived yet.
      _latestLists = [
        for (final list in _latestLists)
          list.id == listId
              ? list.withItems(
                  list.items
                      .where(
                        (i) => i.tmdbId != tmdbId || i.mediaType != mediaType,
                      )
                      .toList(),
                )
              : list,
      ];
    } finally {
      _pendingRemovals.remove(key);
      state = AsyncData(_visible(_latestLists));
    }
  }

  /// Puts a dropped title back in Continue Watching.
  /// Throws an [AppFailure]; the Dropped list reloads either way.
  Future<void> restoreFromDropped(int tmdbId, MediaKind mediaType) =>
      _changeDropped(
        (repo, userId) =>
            repo.restoreToContinueWatching(userId, tmdbId, mediaType.name),
      );

  Future<void> _changeDropped(
    Future<void> Function(WatchProgressRepository repo, String userId) change,
  ) async {
    final userId = ref.read(authProvider).value?.id;
    if (userId == null) return;
    try {
      await change(ref.read(watchProgressRepositoryProvider), userId);
    } finally {
      // Continue Watching follows the local history by itself.
      ref.invalidate(droppedListProvider);
    }
  }

  /// Whether a title is in the Watchlist.
  bool isInWatchlist(int tmdbId, MediaKind mediaType) =>
      _isInList(ListType.watchlist, tmdbId, mediaType);

  /// Whether a title is in Favorites.
  bool isFavorite(int tmdbId, MediaKind mediaType) =>
      _isInList(ListType.favorites, tmdbId, mediaType);

  bool _isInList(ListType type, int tmdbId, MediaKind mediaType) {
    final list = (state.value ?? []).where((l) => l.type == type).firstOrNull;
    return list?.items.any(
          (i) => i.tmdbId == tmdbId && i.mediaType == mediaType,
        ) ??
        false;
  }

  /// Hides the list at once and deletes it unless [undone] completes with
  /// true. On undo the list comes back; on failure it comes back too (the
  /// local copy is deleted only after the server) and the error is rethrown
  /// for the UI to show.
  Future<void> deleteWithUndo(
    String listId, {
    required Future<bool> undone,
  }) async {
    _pendingDeletes.add(listId);
    state = AsyncData(_visible(_latestLists));
    try {
      if (await undone) return;
      await ref.read(listsRepositoryProvider).deleteList(listId);
      _latestLists = _latestLists.where((l) => l.id != listId).toList();
      await _unpin(listId);
    } finally {
      _pendingDeletes.remove(listId);
      state = AsyncData(_visible(_latestLists));
    }
  }

  Future<void> _unpin(String listId) async {
    final pins = ref.read(pinnedListIdsProvider.notifier);
    if (!pins.isPinned(listId)) return;
    try {
      await pins.togglePin(listId);
    } catch (e, st) {
      // Safe to continue: the list is already deleted, and Home shows only
      // pins whose list still exists.
      AppLogger.warn(
        'UserListsNotifier',
        'Unpinning a deleted list failed',
        error: e,
        stackTrace: st,
      );
    }
  }
}

final userListsProvider =
    StreamNotifierProvider<UserListsNotifier, List<UserList>>(() {
      return UserListsNotifier();
    });

/// Whether a title is in the Watchlist or Favorites. Watches the lists, so a
/// heart / bookmark icon follows every change and the first load (REV-203).
final isInSystemListProvider = Provider.autoDispose
    .family<bool, ({int tmdbId, MediaKind mediaType, ListType type})>((
      ref,
      key,
    ) {
      final lists = ref.watch(userListsProvider).value ?? const [];
      final list = lists.where((l) => l.type == key.type).firstOrNull;
      return list?.items.any(
            (i) => i.tmdbId == key.tmdbId && i.mediaType == key.mediaType,
          ) ??
          false;
    });

final droppedListProvider = FutureProvider<UserList?>((ref) async {
  final user = ref.watch(authProvider).value;
  if (user == null) return null;

  final repo = ref.watch(watchHistoryRepositoryProvider);
  final droppedItems = await repo.getDroppedItems(user.id);

  final items = droppedItems.map((history) {
    return UserListItem(
      listId: UserList.droppedId,
      mediaType: history.mediaType,
      tmdbId: history.tmdbId,
      addedAt: history.lastWatchedAt,
      media: history.media,
    );
  }).toList();

  return UserList(
    id: UserList.droppedId,
    userId: user.id,
    name: 'Dropped',
    type: ListType.dropped,
    createdAt: DateTime.now(),
    items: items,
  );
});

/// The user's own lists pinned to Home, in list order. An empty pinned list
/// stays pinned, but Home shows its row only once it has a title (REV-257).
final pinnedHomeListsProvider =
    Provider.autoDispose<AsyncValue<List<UserList>>>((ref) {
      final pinned = ref.watch(pinnedListIdsProvider);
      return ref
          .watch(userListsProvider)
          .whenData(
            (lists) => lists
                .where((l) => pinned.contains(l.id) && l.items.isNotEmpty)
                .toList(),
          );
    });
