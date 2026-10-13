import 'package:cinemuse_app/features/media/domain/media_item.dart';

enum ListType {
  watchlist('watchlist'),
  favorites('favorites'),
  custom('custom'),
  tierlist('tier_list'),
  dropped('dropped');

  const ListType(this.dbName);

  /// The value of the `lists.type` column.
  final String dbName;

  /// Reads `lists.type`. An unknown value is shown as a custom list, so one
  /// new type can't break every list (REV-91).
  static ListType fromDb(String? value) => values.firstWhere(
    (t) => t.dbName == value || t.name == value,
    orElse: () => custom,
  );
}

class UserList {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final ListType type;
  final int sortOrder;
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
    required this.createdAt,
    this.items = const [],
  });

  /// Id of the Dropped list, built from the watch history (REV-107).
  static const droppedId = 'dropped';

  /// Id prefix of a TMDB collection shown as a list; pinned ids use it too.
  static const collectionIdPrefix = 'collection_';

  /// A TMDB collection: shown like a list, but can't be edited.
  bool get isCollection => id.startsWith(collectionIdPrefix);

  /// Whether items can be added, removed or the list edited.
  bool get isReadOnly => isCollection;

  /// Watchlist, Favorites and Dropped: built in, so they can't be renamed or
  /// deleted (REV-277).
  bool get isSystemList =>
      type == ListType.watchlist ||
      type == ListType.favorites ||
      type == ListType.dropped;

  /// Whether the list holds this title (REV-177: tmdbId alone can match
  /// both a movie and a show).
  bool containsTitle(int tmdbId, MediaKind mediaType) =>
      items.any((i) => i.tmdbId == tmdbId && i.mediaType == mediaType);

  /// A TMDB collection shown as a read-only list (the list details sheet).
  factory UserList.fromCollection(
    MediaCollection collection, {
    required String name,
  }) {
    final id = '$collectionIdPrefix${collection.id}';
    final now = DateTime.now();
    return UserList(
      id: id,
      userId: 'system',
      name: name,
      description: collection.overview,
      type: ListType.custom,
      createdAt: now,
      items: [
        for (final media in collection.parts)
          UserListItem(
            listId: id,
            addedAt: now,
            tmdbId: media.tmdbId,
            mediaType: media.mediaType,
            media: media,
          ),
      ],
    );
  }

  factory UserList.fromJson(Map<String, dynamic> json) {
    return UserList(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      type: ListType.fromDb(json['type'] as String?),
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      items:
          (json['list_items'] as List<dynamic>?)
              ?.map((e) => UserListItem.fromJson(e))
              .toList() ??
          [],
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
    final mediaJson = json['media'] as Map<String, dynamic>?;
    return UserListItem(
      listId: json['list_id'] as String,
      mediaType: MediaItem.fromString(json['media_type'] as String? ?? 'movie'),
      tmdbId: json['tmdb_id'] as int,
      sortOrder: json['sort_order'] as int? ?? 0,
      meta: json['meta'] as Map<String, dynamic>? ?? {},
      addedAt: DateTime.parse(json['added_at'] as String),
      media: mediaJson != null ? MediaItem.fromJson(mediaJson) : null,
    );
  }

  MediaItem toMediaItem() {
    if (media != null) return media!;

    // Parse rating/vote_average
    final ratingNum = meta['rating'] as num?;
    final rating = ratingNum?.toDouble();

    // Parse release date/year
    DateTime? parsedReleaseDate;
    final year = meta['year'];
    if (year != null) {
      parsedReleaseDate = DateTime.tryParse('$year-01-01');
    }

    return MediaItem(
      tmdbId: tmdbId,
      mediaType: mediaType,
      titleEn: meta['title']?.toString() ?? 'Unknown',
      titleIt: meta['title']?.toString(), // Fallback
      posterPath: meta['poster_path']?.toString(),
      backdropPath: meta['backdrop_path']?.toString(),
      releaseDate: parsedReleaseDate,
      voteAverage: rating,
      updatedAt: addedAt,
    );
  }
}
