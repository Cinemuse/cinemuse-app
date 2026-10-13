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

  /// One title = type + id: TMDB movie and series ids overlap (REV-98).
  String get titleKey => '${mediaType.name}-$tmdbId';

  factory WatchHistory.fromJson(Map<String, dynamic> json) {
    return WatchHistory(
      userId: json['user_id'] as String,
      tmdbId: json['tmdb_id'] as int,
      mediaType: MediaItem.fromString(
        json['media_type']?.toString() ?? 'movie',
      ),
      status: json['status'] != null
          ? WatchStatus.values.firstWhere(
              (e) => e.name == json['status'],
              orElse: () => WatchStatus.watching,
            )
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
