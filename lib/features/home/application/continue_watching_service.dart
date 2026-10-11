import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Continue Watching card actions. The row updates by itself: these
/// write to the watch history, which the row watches.
class ContinueWatchingService {
  final Ref _ref;

  ContinueWatchingService(this._ref);

  String? get _userId => _ref.read(authProvider).value?.id;

  /// Moves [item] to the Dropped list.
  Future<void> drop(WatchHistory item) async {
    final userId = _userId;
    if (userId == null) return;
    await _ref
        .read(watchHistoryRepositoryProvider)
        .dropFromContinueWatching(userId, item.tmdbId);
    _ref.invalidate(droppedListProvider);
  }

  /// Ends a rewatch of [item].
  Future<void> cancelRewatch(WatchHistory item) async {
    final userId = _userId;
    if (userId == null) return;
    await _ref
        .read(watchHistoryRepositoryProvider)
        .cancelRewatch(userId, item.tmdbId, item.mediaType.name);
  }

  /// Clears the progress of [item] ("Remove from Continue Watching").
  Future<void> clearProgress(WatchHistory item) async {
    final userId = _userId;
    if (userId == null) return;
    await _ref
        .read(watchHistoryRepositoryProvider)
        .clearProgress(
          userId: userId,
          tmdbId: item.tmdbId,
          mediaType: item.mediaType.name,
        );
  }
}

// Not autoDispose: it holds no data, and an action still uses its ref after
// the await (an autoDispose ref read once from a callback is disposed then).
final continueWatchingServiceProvider = Provider<ContinueWatchingService>(
  ContinueWatchingService.new,
);
