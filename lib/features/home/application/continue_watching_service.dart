import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/application/title_removals.dart';
import 'package:cinemuse_app/features/media/application/watch_history_store.dart';
import 'package:cinemuse_app/features/media/data/watch_progress_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Continue Watching card actions. The row updates by itself: these
/// write to the watch history, which the row watches.
class ContinueWatchingService {
  final Ref _ref;

  ContinueWatchingService(this._ref);

  String? get _userId => _ref.read(authProvider).value?.id;
  TitleRemovals get _removals => _ref.read(titleRemovalsProvider);

  /// Moves [item] to the Dropped list.
  Future<void> drop(WatchHistory item) async {
    final userId = _userId;
    if (userId == null) return;
    await _removals.after(item.titleKey);
    await _ref
        .read(watchProgressRepositoryProvider)
        .dropFromContinueWatching(userId, item.tmdbId, item.mediaType.name);
    _ref.invalidate(droppedListProvider);
  }

  /// Shows [item] where it was before its rewatch at once ("Stop
  /// rewatching") and ends the rewatch unless [undone] completes with true
  /// (see [TitleRemovals.removeUnlessUndone]).
  Future<void> cancelRewatch(
    WatchHistory item, {
    required Future<bool> undone,
  }) async {
    final userId = _userId;
    if (userId == null) return;
    final repository = _ref.read(watchProgressRepositoryProvider);
    final end = item.mediaType == MediaKind.movie
        ? null
        : await repository.rewatchEnd(userId, item.tmdbId);
    await _changeUnlessUndone(
      item,
      undone: undone,
      shown: (row) => row.rewatchCancelled(end, now: DateTime.now()),
      change: () => repository.cancelRewatch(
        userId,
        item.tmdbId,
        item.mediaType.name,
        end: end,
      ),
      action: 'cancelRewatch',
    );
  }

  /// Shows [item]'s progress cleared at once ("Remove from Continue
  /// Watching") and clears it unless [undone] completes with true (see
  /// [TitleRemovals.removeUnlessUndone]).
  Future<void> clearProgress(
    WatchHistory item, {
    required Future<bool> undone,
  }) async {
    final userId = _userId;
    if (userId == null) return;
    await _changeUnlessUndone(
      item,
      undone: undone,
      shown: (row) => row.progressCleared(),
      change: () => _ref
          .read(watchProgressRepositoryProvider)
          .clearProgress(
            userId: userId,
            tmdbId: item.tmdbId,
            mediaType: item.mediaType.name,
          ),
      action: 'clearProgress',
    );
  }

  Future<void> _changeUnlessUndone(
    WatchHistory item, {
    required Future<bool> undone,
    required WatchHistory Function(WatchHistory) shown,
    required Future<void> Function() change,
    required String action,
  }) async {
    final pending = _ref.read(pendingWatchChangesProvider.notifier);
    pending.show(item, shown);
    await _removals.removeUnlessUndone(
      title: item.titleKey,
      undone: undone,
      remove: change,
      showAgain: () => pending.showAgain(item),
      action: action,
    );
  }
}

// Not autoDispose: it holds no data, and an action still uses its ref after
// the await (an autoDispose ref read once from a callback is disposed then).
final continueWatchingServiceProvider = Provider<ContinueWatchingService>(
  ContinueWatchingService.new,
);
