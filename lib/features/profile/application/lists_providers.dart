import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/profile/data/lists_repository.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  List<UserList> _latestLists = const [];

  List<UserList> _visible(List<UserList> lists) =>
      lists.where((l) => !_pendingDeletes.contains(l.id)).toList();

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
      // Cache the item before adding it to ensure FK constraints are met
      try {
        await ref.read(watchHistoryRepositoryProvider).saveMediaItem(media);
      } catch (e) {
        debugPrint('Background caching failed: $e');
      }

      await repo.addItemToList(
        listId: targetList.id,
        tmdbId: media.tmdbId,
        mediaType: media.mediaType,
        meta: {
          'title':
              media.getLocalizedTitle('en') ??
              media.getLocalizedTitle('it') ??
              'Unknown',
          'poster_path': media.posterPath,
          'backdrop_path': media.backdropPath,
          'rating': media.voteAverage,
          'year': media.releaseDate?.year,
        },
      );
    }
    // No need to invalidateSelf(), the repository updates the local Drift DB
    // which automatically triggers a new event in our stream.
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

    // Cache the item before adding it to ensure FK constraints are met
    try {
      await ref.read(watchHistoryRepositoryProvider).saveMediaItem(media);
    } catch (e) {
      debugPrint('Background caching failed: $e');
    }

    await repo.addItemToList(
      listId: listId,
      tmdbId: media.tmdbId,
      mediaType: media.mediaType,
      meta: {
        'title':
            media.getLocalizedTitle('en') ??
            media.getLocalizedTitle('it') ??
            'Unknown',
        'poster_path': media.posterPath,
        'backdrop_path': media.backdropPath,
        'rating': media.voteAverage,
        'year': media.releaseDate?.year,
      },
    );
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
  /// true. On undo the list comes back; on failure it comes back too (after
  /// a sync) and the error is rethrown for the UI to show.
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
      final pins = ref.read(pinnedListIdsProvider.notifier);
      if (pins.isPinned(listId)) await pins.togglePin(listId);
    } catch (_) {
      // The local copy may already be gone: sync it back from the server.
      final userId = ref.read(authProvider).value?.id;
      if (userId != null) {
        unawaited(
          ref
              .read(listsRepositoryProvider)
              .syncUserLists(userId)
              .catchError(
                (Object e) => AppLogger.warn(
                  'Lists',
                  'Sync after a failed delete failed',
                  error: e,
                ),
              ),
        );
      }
      rethrow;
    } finally {
      _pendingDeletes.remove(listId);
      state = AsyncData(_visible(_latestLists));
    }
  }
}

final userListsProvider =
    StreamNotifierProvider<UserListsNotifier, List<UserList>>(() {
      return UserListsNotifier();
    });

final droppedListProvider = FutureProvider<UserList?>((ref) async {
  final user = ref.watch(authProvider).value;
  if (user == null) return null;

  final repo = ref.watch(watchHistoryRepositoryProvider);
  final droppedItems = await repo.getDroppedItems(user.id);

  final items = droppedItems.map((history) {
    final media = history.media;
    return UserListItem(
      listId: 'dropped',
      mediaType: history.mediaType,
      tmdbId: history.tmdbId,
      addedAt: history.lastWatchedAt,
      media: media,
      meta: media != null
          ? {
              'title':
                  media.getLocalizedTitle('en') ??
                  media.getLocalizedTitle('it') ??
                  'Unknown',
              'poster_path': media.posterPath,
              'backdrop_path': media.backdropPath,
              'rating': media.voteAverage,
              'year': media.releaseDate?.year,
            }
          : {},
    );
  }).toList();

  return UserList(
    id: 'dropped',
    userId: user.id,
    name: 'Dropped',
    type: ListType.dropped,
    createdAt: DateTime.now(),
    items: items,
  );
});

class PinnedListIdsNotifier extends StateNotifier<Set<String>> {
  PinnedListIdsNotifier() : super(const {}) {
    _load();
  }

  static const _keyPinnedLists = 'pinned_list_ids';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyPinnedLists) ?? [];
    state = list.toSet();
  }

  Future<void> togglePin(String listId) async {
    final updated = Set<String>.from(state);
    if (updated.contains(listId)) {
      updated.remove(listId);
    } else {
      updated.add(listId);
    }
    state = updated;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyPinnedLists, updated.toList());
  }

  bool isPinned(String listId) {
    return state.contains(listId);
  }
}

final pinnedListIdsProvider =
    StateNotifierProvider<PinnedListIdsNotifier, Set<String>>((ref) {
      return PinnedListIdsNotifier();
    });
