/// Domain models for TVTime comment data.
///
/// These models represent the comment and user data returned by the
/// TVTime internal comments API. They are intentionally kept free of
/// any UI or service-layer concerns.

class TvTimeUser {
  final int id;
  final String name;
  final String? avatarUrl;

  const TvTimeUser({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  factory TvTimeUser.fromJson(Map<String, dynamic> json) {
    String? avatar;
    if (json['avatar'] is Map) {
      avatar = json['avatar']['url']?.toString();
    }
    
    return TvTimeUser(
      id: _parseInt(json['id']),
      name: json['name']?.toString() ?? 'Unknown User',
      avatarUrl: _nullIfEmpty(avatar),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar_url': avatarUrl,
      };

  static String? _nullIfEmpty(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }
  
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }
}

class TvTimeComment {
  final String uuid;
  final String text;
  final DateTime? createdAt;
  final int likeCount;
  final int replyCount;
  final int reportCount;
  final bool isSpoiler;
  final String language;
  final TvTimeUser user;
  final String? imageUrl;
  final bool isMeme;
  final int? imageWidth;
  final int? imageHeight;
  final List<TvTimeComment> replies;

  const TvTimeComment({
    required this.uuid,
    required this.text,
    this.createdAt,
    required this.likeCount,
    this.replyCount = 0,
    this.reportCount = 0,
    this.isSpoiler = false,
    this.language = 'en',
    required this.user,
    this.imageUrl,
    this.isMeme = false,
    this.imageWidth,
    this.imageHeight,
    this.replies = const [],
  });

  factory TvTimeComment.fromJson(Map<String, dynamic> json) {
    final rawReplies = json['replies'] as List<dynamic>? ?? [];

    String? image;
    bool meme = false;
    int? imgWidth;
    int? imgHeight;
    
    if (json['image'] is Map) {
      image = json['image']['url']?.toString();
      meme = json['image']['is_meme'] == true;
      imgWidth = _parseInt(json['image']['width']);
      imgHeight = _parseInt(json['image']['height']);
      
      // If parsing fails or gives 0, make it null
      if (imgWidth == 0) imgWidth = null;
      if (imgHeight == 0) imgHeight = null;
    }

    return TvTimeComment(
      uuid: json['uuid']?.toString() ?? '',
      text: (json['text']?.toString() ?? '').trim(),
      createdAt: _parseDate(json['created_at']?.toString()),
      likeCount: _parseInt(json['like_count']),
      replyCount: _parseInt(json['reply_count']),
      reportCount: _parseInt(json['report_count']),
      isSpoiler: json['is_spoiler'] == true,
      language: json['language']?.toString() ?? 'en',
      user: TvTimeUser.fromJson(
        (json['user'] as Map<String, dynamic>?) ?? {},
      ),
      imageUrl: _nullIfEmpty(image),
      isMeme: meme,
      imageWidth: imgWidth,
      imageHeight: imgHeight,
      replies: rawReplies
          .whereType<Map<String, dynamic>>()
          .map(TvTimeComment.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'text': text,
        'created_at': createdAt?.toIso8601String(),
        'like_count': likeCount,
        'reply_count': replyCount,
        'report_count': reportCount,
        'is_spoiler': isSpoiler,
        'language': language,
        'user': user.toJson(),
        'image_url': imageUrl,
        'is_meme': isMeme,
        'replies': replies.map((r) => r.toJson()).toList(),
      };

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  static String? _nullIfEmpty(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }
}
