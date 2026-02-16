import 'package:cinemuse_app/features/media/domain/media_item.dart';

enum ListType {
  watchlist,
  favorites,
  custom,
  tierlist,
}

class UserList {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final ListType type;
  final int sortOrder;
  final Map<String, dynamic> settings;
  final DateTime createdAt;
  
  // For easy display
  final List<UserListItem> items;

  UserList({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.type,
    this.sortOrder = 0,
    this.settings = const {},
    required this.createdAt,
    this.items = const [],
  });

  factory UserList.fromJson(Map<String, dynamic> json) {
    // Determine type from string
    ListType type = ListType.custom;
    final typeStr = json['type'] as String?;
    if (typeStr == 'watchlist') type = ListType.watchlist;
    else if (typeStr == 'favorites') type = ListType.favorites;
    else if (typeStr == 'tierlist') type = ListType.tierlist;

    return UserList(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      type: type,
      sortOrder: json['sort_order'] as int? ?? 0,
      settings: json['settings'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
      items: (json['list_items'] as List<dynamic>?)
          ?.map((e) => UserListItem.fromJson(e))
          .toList() ?? [],
    );
  }
}

class UserListItem {
  final String listId;
  final MediaKind mediaType;
  final int tmdbId;
  final int sortOrder;
  final Map<String, dynamic> meta;
  final DateTime addedAt;
  
  // Joined media details (from meta or another join)
  final MediaItem? media;

  UserListItem({
    required this.listId,
    required this.mediaType,
    required this.tmdbId,
    this.sortOrder = 0,
    this.meta = const {},
    required this.addedAt,
    this.media,
  });

  factory UserListItem.fromJson(Map<String, dynamic> json) {
    return UserListItem(
      listId: json['list_id'] as String,
      mediaType: MediaItem.fromString(json['media_type'] as String? ?? 'movie'),
      tmdbId: json['media_tmdb_id'] as int,
      sortOrder: json['sort_order'] as int? ?? 0,
      meta: json['meta'] as Map<String, dynamic>? ?? {},
      addedAt: DateTime.parse(json['added_at'] as String),
      // We'll hydrate the 'media' property using the meta or a cache later
    );
  }
}
