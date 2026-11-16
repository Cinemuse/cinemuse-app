import 'dart:async';

import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';

/// The user's watch history, one row per title, keyed by
/// [WatchHistory.titleKey] (type + id: a movie and a show can share a
/// tmdbId, REV-195). Updates live when the local database changes.
final watchHistoryStoreProvider = StreamProvider<Map<String, WatchHistory>>((
  ref,
) {
  final user = ref.watch(authProvider).asData?.value;
  if (user == null) return Stream.value({});

  final repository = ref.watch(watchHistoryRepositoryProvider);

  // Refresh the local copy from Supabase in the background. The local copy
  // is shown meanwhile, so a failure (e.g. offline) is only logged (DATA-07).
  unawaited(
    repository.syncWatchHistory(user.id).catchError((Object e, StackTrace st) {
      AppLogger.warn(
        'WatchHistoryStore',
        'Background sync failed',
        error: e,
        stackTrace: st,
      );
    }),
  );

  return repository
      .watchHistory(user.id)
      .map((list) => {for (final item in list) item.titleKey: item});
});

/// A watch change waiting for its Undo message: the row as it was before,
/// and the row the screens show meanwhile.
typedef PendingWatchChange = ({WatchHistory before, WatchHistory shown});

/// The watch changes ("Clear progress", "Stop rewatching") that wait for
/// their Undo message, by [WatchHistory.titleKey].
class PendingWatchChanges extends Notifier<Map<String, PendingWatchChange>> {
  @override
  Map<String, PendingWatchChange> build() => const {};

  /// Shows [row] as [change] makes it until the change is sent or undone.
  void show(WatchHistory row, WatchHistory Function(WatchHistory) change) {
    final stored = ref.read(watchHistoryStoreProvider).value ?? const {};
    final before = stored[row.titleKey] ?? row;
    state = {
      // Drops the changes already sent: their rows have changed.
      for (final e in state.entries)
        if (_isUnchanged(stored[e.key], e.value.before)) e.key: e.value,
      row.titleKey: (before: before, shown: change(before)),
    };
  }

  void showAgain(WatchHistory row) => state = {...state}..remove(row.titleKey);
}

final pendingWatchChangesProvider =
    NotifierProvider<PendingWatchChanges, Map<String, PendingWatchChange>>(
      PendingWatchChanges.new,
    );

bool _isUnchanged(WatchHistory? stored, WatchHistory before) =>
    stored != null &&
    stored.status == before.status &&
    stored.season == before.season &&
    stored.episode == before.episode &&
    stored.progressSeconds == before.progressSeconds &&
    stored.lastWatchedAt == before.lastWatchedAt;

/// The watch history as the screens show it: the changes waiting for their
/// Undo message already applied. Each applies while the stored row is the
/// one it changed, so it ends by itself when the changed row arrives.
final shownWatchHistoryProvider =
    Provider<AsyncValue<Map<String, WatchHistory>>>((ref) {
      final pending = ref.watch(pendingWatchChangesProvider);
      return ref.watch(watchHistoryStoreProvider).whenData((stored) {
        if (pending.isEmpty) return stored;
        return {
          for (final MapEntry(:key, :value) in stored.entries)
            key: switch (pending[key]) {
              final change? when _isUnchanged(value, change.before) =>
                change.shown,
              _ => value,
            },
        };
      });
    });
