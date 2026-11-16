import 'package:cinemuse_app/core/data/database.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Narrows a `watch_history` query to one title. REV-177: a movie and a
/// show can share a tmdbId, so the media type is always needed.
PostgrestFilterBuilder<T> whereTitleRow<T>(
  PostgrestFilterBuilder<T> query,
  String userId,
  int tmdbId,
  String mediaType,
) => query
    .eq('user_id', userId)
    .eq('tmdb_id', tmdbId)
    .eq('media_type', mediaType);

/// A `watch_history` row from Supabase as a local Drift entry.
LocalWatchHistoriesCompanion localEntryFromRemote(
  String userId,
  Map<String, dynamic> json,
) {
  final lastWatched = json['last_watched_at'] != null
      ? DateTime.parse(json['last_watched_at'])
      : DateTime.now();

  return LocalWatchHistoriesCompanion(
    userId: Value(userId),
    tmdbId: Value(json['tmdb_id'] as int? ?? 0),
    mediaType: Value(json['media_type'] as String? ?? 'movie'),
    status: Value(json['status'] as String? ?? 'watching'),
    progressSeconds: Value(json['progress_seconds'] as int? ?? 0),
    totalDuration: Value(json['total_duration'] as int? ?? 0),
    season: Value(json['season'] as int? ?? 0),
    episode: Value(json['episode'] as int? ?? 0),
    lastWatchedAt: Value(lastWatched),
  );
}

/// Copies the title's row returned by a watch RPC into the local cache
/// (no row = the title has none left). Every RPC that changes a title
/// returns its row, so this is the one local write after it (REV-186).
Future<void> cacheReturnedRow(
  AppDatabase db,
  String userId,
  int tmdbId,
  String mediaType,
  dynamic rows,
) async {
  final row = (rows as List).firstOrNull as Map<String, dynamic>?;
  if (row == null) {
    await db.deleteWatchHistoryItem(userId, tmdbId, mediaType);
  } else {
    await db.upsertWatchHistory(localEntryFromRemote(userId, row));
  }
}
