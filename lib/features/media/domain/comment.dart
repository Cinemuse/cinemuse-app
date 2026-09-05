import 'package:equatable/equatable.dart';

/// Identifies the upstream source/platform of a comment or review.
enum CommentSource {
  serializd,
  letterboxd,
  tmdb,
  imdb,
  cinemuse,
}

/// Represents the author of a comment or review.
class CommentAuthor extends Equatable {
  final String id;
  final String username;
  final String? avatarUrl;
  final bool isCinemuseUser;

  const CommentAuthor({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.isCinemuseUser = false,
  });

  @override
  List<Object?> get props => [id, username, avatarUrl, isCinemuseUser];
}

/// Unified domain entity for all community feedback:
/// - Serializd episodic comments & reactions
/// - Media-level reviews (IMDb / TMDB)
/// - Native Cinemuse user reviews & comments
class Comment extends Equatable {
  final String id;
  final CommentAuthor author;
  final String text;
  final String? title;
  final double? rating;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int likeCount;
  final int replyCount;
  final bool isSpoiler;
  final CommentSource source;
  final List<Comment> replies;
  final bool isOwnComment;

  const Comment({
    required this.id,
    required this.author,
    required this.text,
    this.title,
    this.rating,
    this.createdAt,
    this.updatedAt,
    this.likeCount = 0,
    this.replyCount = 0,
    this.isSpoiler = false,
    required this.source,
    this.replies = const [],
    this.isOwnComment = false,
  });

  Comment copyWith({
    String? id,
    CommentAuthor? author,
    String? text,
    String? title,
    double? rating,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? likeCount,
    int? replyCount,
    bool? isSpoiler,
    CommentSource? source,
    List<Comment>? replies,
    bool? isOwnComment,
  }) {
    return Comment(
      id: id ?? this.id,
      author: author ?? this.author,
      text: text ?? this.text,
      title: title ?? this.title,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likeCount: likeCount ?? this.likeCount,
      replyCount: replyCount ?? this.replyCount,
      isSpoiler: isSpoiler ?? this.isSpoiler,
      source: source ?? this.source,
      replies: replies ?? this.replies,
      isOwnComment: isOwnComment ?? this.isOwnComment,
    );
  }

  @override
  List<Object?> get props => [
    id,
    author,
    text,
    title,
    rating,
    createdAt,
    updatedAt,
    likeCount,
    replyCount,
    isSpoiler,
    source,
    replies,
    isOwnComment,
  ];
}
