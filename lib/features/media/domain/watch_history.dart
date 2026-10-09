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
      media: json['media_cache'] != null
          ? (json['media_cache'] is List
                ? (json['media_cache'] as List).isNotEmpty
                      ? MediaItem.fromJson(json['media_cache'][0])
                      : null
                : MediaItem.fromJson(json['media_cache']))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'tmdb_id': tmdbId,
      'media_type': mediaType.name,
      'status': status?.name,
      'progress_seconds': progressSeconds,
      'total_duration': totalDuration,
      'watch_count': watchCount,
      'last_watched_at': lastWatchedAt.toIso8601String(),
      'season': season,
      'episode': episode,
    };
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

  WatchLog copyWith({
    dynamic id,
    String? userId,
    int? tmdbId,
    MediaKind? mediaType,
    int? season,
    int? episode,
    DateTime? loggedAt,
    int? durationWatchedSeconds,
    bool? isOptimistic,
  }) {
    return WatchLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tmdbId: tmdbId ?? this.tmdbId,
      mediaType: mediaType ?? this.mediaType,
      season: season ?? this.season,
      episode: episode ?? this.episode,
      loggedAt: loggedAt ?? this.loggedAt,
      durationWatchedSeconds:
          durationWatchedSeconds ?? this.durationWatchedSeconds,
      isOptimistic: isOptimistic ?? this.isOptimistic,
    );
  }

  factory WatchLog.fromJson(Map<String, dynamic> json) {
    final loggedAtStr = json['logged_at']?.toString();
    final loggedAt = loggedAtStr != null
        ? DateTime.tryParse(loggedAtStr) ?? DateTime.now()
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
      isOptimistic: json['is_optimistic'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'tmdb_id': tmdbId,
      'media_type': mediaType.name,
      if (season != null) 'season': season,
      if (episode != null) 'episode': episode,
      'logged_at': loggedAt.toIso8601String(),
      if (durationWatchedSeconds != null)
        'duration_watched_seconds': durationWatchedSeconds,
      if (isOptimistic) 'is_optimistic': isOptimistic,
    };
  }
}
