import 'package:cinemuse_app/features/media/domain/media_item.dart';

enum WatchStatus {
  watching,
  completed,
  dropped;

  static WatchStatus fromJson(String value) {
    return WatchStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => WatchStatus.watching,
    );
  }
}

/// Where "Stop rewatching" takes a show: the episode after the highest one
/// logged, or that highest one, [finished], when no later episode has aired
/// (or TMDB can't be reached).
typedef RewatchEnd = ({int season, int episode, bool finished});

class WatchHistory {
  final String userId;
  final int tmdbId;
  final MediaKind mediaType;
  final WatchStatus? status;
  final int progressSeconds;
  final int? totalDuration;
  final int watchCount;
  final DateTime lastWatchedAt;

  final int? season;
  final int? episode;

  // Optional embedded MediaItem if joined
  final MediaItem? media;

  WatchHistory({
    required this.userId,
    required this.tmdbId,
    required this.mediaType,
    this.status,
    this.progressSeconds = 0,
    this.totalDuration,
    this.watchCount = 0,
    required this.lastWatchedAt,
    this.season,
    this.episode,
    this.media,
  });

  bool get isCompleted => status == WatchStatus.completed;

  /// Time still to watch, rounded up to the minute (REV-245); null when the
  /// length is unknown or nothing is left.
  Duration? get timeLeft {
    final total = totalDuration;
    if (total == null || total <= 0) return null;
    final seconds = total - progressSeconds;
    if (seconds <= 0) return null;
    return Duration(minutes: (seconds / 60).ceil());
  }

  /// One title = type + id: TMDB movie and series ids overlap (REV-98).
  String get titleKey => '${mediaType.name}-$tmdbId';

  /// This row after "Clear progress", as the server makes it: a movie
  /// leaves Continue Watching, a show stays on its episode from the start.
  WatchHistory progressCleared() => WatchHistory(
    userId: userId,
    tmdbId: tmdbId,
    mediaType: mediaType,
    status: mediaType == MediaKind.movie ? WatchStatus.completed : status,
    totalDuration: totalDuration,
    watchCount: watchCount,
    lastWatchedAt: lastWatchedAt,
    season: season,
    episode: episode,
    media: media,
  );

  /// This row after "Stop rewatching", as the server makes it: a movie
  /// leaves Continue Watching, a show goes to [end] from the start, moved to
  /// the front (a finished one leaves Continue Watching). A show with no
  /// [end] has nothing logged, and the server leaves it as it is.
  WatchHistory rewatchCancelled(RewatchEnd? end, {required DateTime now}) {
    if (mediaType != MediaKind.movie && end == null) return this;
    return WatchHistory(
      userId: userId,
      tmdbId: tmdbId,
      mediaType: mediaType,
      status: end == null || end.finished
          ? WatchStatus.completed
          : WatchStatus.watching,
      totalDuration: end == null ? totalDuration : 0,
      watchCount: watchCount,
      lastWatchedAt: end == null ? lastWatchedAt : now,
      season: end?.season ?? season,
      episode: end?.episode ?? episode,
      media: media,
    );
  }

  factory WatchHistory.fromJson(Map<String, dynamic> json) {
    return WatchHistory(
      userId: json['user_id'] as String,
      tmdbId: json['tmdb_id'] as int,
      mediaType: MediaItem.fromString(
        json['media_type']?.toString() ?? 'movie',
      ),
      status: json['status'] != null
          ? WatchStatus.fromJson(json['status'].toString())
          : null,
      progressSeconds: json['progress_seconds'] as int? ?? 0,
      totalDuration: json['total_duration'] as int?,
      watchCount: json['watch_count'] as int? ?? 0,
      lastWatchedAt: DateTime.parse(json['last_watched_at'] as String),
      season: json['season'] as int?,
      episode: json['episode'] as int?,
    );
  }
}

/// Strongly-typed domain entity representing an individual watch log entry.
class WatchLog {
  final dynamic id;
  final String userId;
  final int tmdbId;
  final MediaKind mediaType;
  final int? season;
  final int? episode;
  final DateTime loggedAt;
  final int? durationWatchedSeconds;
  final bool isOptimistic;

  const WatchLog({
    this.id,
    this.userId = '',
    required this.tmdbId,
    required this.mediaType,
    this.season,
    this.episode,
    required this.loggedAt,
    this.durationWatchedSeconds,
    this.isOptimistic = false,
  });

  /// Key that matches an optimistic log with the saved one: the same moment
  /// in UTC, to the second. The app keeps local times and the server sends
  /// UTC (REV-178), so both become UTC first.
  static String timestampKey(DateTime date) {
    final utc = date.toUtc();
    return DateTime.utc(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute,
      utc.second,
    ).toIso8601String();
  }

  factory WatchLog.fromJson(Map<String, dynamic> json) {
    final loggedAtStr = json['logged_at']?.toString();
    // The server sends UTC; the app shows local time (REV-178).
    final loggedAt = loggedAtStr != null
        ? DateTime.tryParse(loggedAtStr)?.toLocal() ?? DateTime.now()
        : DateTime.now();

    return WatchLog(
      id: json['id'],
      userId: json['user_id'] as String? ?? '',
      tmdbId: (json['tmdb_id'] as num?)?.toInt() ?? 0,
      mediaType: MediaItem.fromString(
        json['media_type']?.toString() ?? 'movie',
      ),
      season: (json['season'] as num?)?.toInt(),
      episode: (json['episode'] as num?)?.toInt(),
      loggedAt: loggedAt,
      durationWatchedSeconds: (json['duration_watched_seconds'] as num?)
          ?.toInt(),
    );
  }
}
