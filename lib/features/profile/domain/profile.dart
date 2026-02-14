class Profile {
  final String id;
  final String? username;
  final String? avatarUrl;
  final int totalMinutesWatched;
  final int moviesWatchedCount;
  final int episodesWatchedCount;
  final Map<String, dynamic> preferences;
  final DateTime createdAt;
  final DateTime updatedAt;

  Profile({
    required this.id,
    this.username,
    this.avatarUrl,
    this.totalMinutesWatched = 0,
    this.moviesWatchedCount = 0,
    this.episodesWatchedCount = 0,
    this.preferences = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      totalMinutesWatched: json['total_minutes_watched'] as int? ?? 0,
      moviesWatchedCount: json['movies_watched_count'] as int? ?? 0,
      episodesWatchedCount: json['episodes_watched_count'] as int? ?? 0,
      preferences: json['preferences'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'avatar_url': avatarUrl,
      'total_minutes_watched': totalMinutesWatched,
      'movies_watched_count': moviesWatchedCount,
      'episodes_watched_count': episodesWatchedCount,
      'preferences': preferences,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
