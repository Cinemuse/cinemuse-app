import 'package:equatable/equatable.dart';

/// Identifies the upstream source/platform of a comment or review.
enum CommentSource { serializd, letterboxd, tmdb, imdb, cinemuse }

/// Represents the author of a comment or review.
class CommentAuthor extends Equatable {
  final String id;
  final String username;
  final String? avatarUrl;

  const CommentAuthor({
    required this.id,
    required this.username,
    this.avatarUrl,
  });

  @override
  List<Object?> get props => [id, username, avatarUrl];
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
  });

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
  ];
}
