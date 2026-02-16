import 'package:cinemuse_app/features/media/domain/media_item.dart';

enum WatchStatus {
  watching,
  completed,
  dropped,
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

  factory WatchHistory.fromJson(Map<String, dynamic> json) {
    return WatchHistory(
      userId: json['user_id'] as String,
      tmdbId: json['tmdb_id'] as int,
      mediaType: MediaItem.fromString(json['media_type']?.toString() ?? 'movie'),
      status: json['status'] != null 
          ? WatchStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => WatchStatus.watching)
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
