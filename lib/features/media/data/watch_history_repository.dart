import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/error/supabase_failure.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/core/utils/stream_debounce.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/data/watch_history_rows.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final watchHistoryRepositoryProvider = Provider<WatchHistoryRepository>((ref) {
  return WatchHistoryRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(mediaRepositoryProvider),
    ref.watch(appDatabaseProvider),
  );
});

/// Reads the watch history (one row per title) and copies it from Supabase
/// into the local Drift cache. Writes are in `WatchProgressRepository` and
/// `WatchLogsRepository` (ARCH-02).
class WatchHistoryRepository {
  static const _logTag = 'WatchHistoryRepository';

  final SupabaseClient _client;
  final MediaRepository _mediaRepo;
  final AppDatabase _db;

  WatchHistoryRepository(this._client, this._mediaRepo, this._db);

  /// The dropped titles, newest first. Throws an [AppFailure].
  Future<List<WatchHistory>> getDroppedItems(String userId) async {
    final response = await _client
        .from('watch_history')
        .select()
        .eq('user_id', userId)
        .eq('status', 'dropped')
        .order('last_watched_at', ascending: false)
        .withAppFailure();

    return (response as List).map((e) => WatchHistory.fromJson(e)).toList();
  }

  /// The title's row while it is "watching", else null. Throws an
  /// [AppFailure].
  Future<WatchHistory?> getHistoryItem(
    String userId,
    String tmdbId,
    String mediaType,
  ) async {
    final id = int.tryParse(tmdbId);
    if (id == null) return null;
    final response = await whereTitleRow(
      _client.from('watch_history').select(),
      userId,
      id,
      mediaType,
    ).eq('status', 'watching').maybeSingle().withAppFailure();

    if (response == null) return null;
    return WatchHistory.fromJson(response);
  }

  /// The local history, live, with each title's media details. Debounced,
  /// so a burst of local writes gives one update (PERF-02).
  Stream<List<WatchHistory>> watchHistory(String userId) {
    return _db
        .watchWatchHistory(userId)
        .debounce(const Duration(milliseconds: 300))
        .asyncMap((list) => Future.wait(list.map(_historyFromLocal)));
  }

  /// The local history once, with each title's media details.
  Future<List<WatchHistory>> getLocalHistory(String userId) async {
    final list = await _db.getWatchHistory(userId);
    return Future.wait(list.map(_historyFromLocal));
  }

  /// A local Drift row as a [WatchHistory], with its media details.
  Future<WatchHistory> _historyFromLocal(LocalWatchHistory local) async {
    final mediaKind = MediaItem.fromString(local.mediaType);
    return WatchHistory(
      userId: local.userId,
      tmdbId: local.tmdbId,
      mediaType: mediaKind,
      status: WatchStatus.fromJson(local.status),
      progressSeconds: local.progressSeconds,
      totalDuration: local.totalDuration,
      lastWatchedAt: local.lastWatchedAt,
      season: local.season,
      episode: local.episode,
      media: await _mediaRepo.getMediaItem(local.tmdbId, mediaKind),
    );
  }

  Stream<List<WatchHistory>> watchSeriesHistory(String userId, int tmdbId) {
    return watchHistory(userId).map(
      (list) => list
          .where((e) => e.tmdbId == tmdbId && e.mediaType == MediaKind.tv)
          .toList(),
    );
  }

  /// Syncs watch history from Supabase to Drift.
  /// Should be called on app startup or periodically.
  Future<void> syncWatchHistory(String userId) async {
    try {
      final allRemoteData = <dynamic>[];
      int offset = 0;
      const limit = 1000;
      bool hasMore = true;

      while (hasMore) {
        final remoteData = await _client
            .from('watch_history')
            .select()
            .eq('user_id', userId)
            // REV-185: a fixed order, or pages can repeat or skip rows.
            .order('tmdb_id')
            .order('media_type')
            .range(offset, offset + limit - 1)
            .withAppFailure();

        final dataList = remoteData as List<dynamic>;
        allRemoteData.addAll(dataList);

        if (dataList.length < limit) {
          hasMore = false;
        } else {
          offset += limit;
        }
      }

      final companions = allRemoteData
          .map((json) => localEntryFromRemote(userId, json))
          .toList();

      await _db.syncWatchHistory(userId, companions);
    } catch (e, s) {
      // Safe to go on: the local cache keeps its last copy until the next
      // sync.
      AppLogger.warn(
        _logTag,
        'Failed to sync remote watch history to Drift database for user: '
        '$userId',
        error: e,
        stackTrace: s,
      );
    }
  }
}
