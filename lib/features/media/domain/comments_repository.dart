import 'package:equatable/equatable.dart';
import 'package:cinemuse_app/features/media/domain/comment.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';

/// Base class for all comment/review requests.
abstract class CommentsRequest extends Equatable {
  const CommentsRequest();
}

/// Request for episode-level community comments & reactions.
class EpisodeCommentsRequest extends CommentsRequest {
  final int tmdbShowId;
  final int seasonNumber;
  final int episodeNumber;
  final int? seasonId;
  final String? imdbId;

  const EpisodeCommentsRequest({
    required this.tmdbShowId,
    required this.seasonNumber,
    required this.episodeNumber,
    this.seasonId,
    this.imdbId,
  });

  @override
  List<Object?> get props => [
    tmdbShowId,
    seasonNumber,
    episodeNumber,
    seasonId,
    imdbId,
  ];
}

/// Request for top-level media reviews (movies or series).
class MediaReviewsRequest extends CommentsRequest {
  final int tmdbId;
  final MediaKind mediaType;
  final String? imdbId;
  final String? title;
  final int? year;

  const MediaReviewsRequest({
    required this.tmdbId,
    required this.mediaType,
    this.imdbId,
    this.title,
    this.year,
  });

  @override
  List<Object?> get props => [tmdbId, mediaType, imdbId, title, year];
}

/// Contract for fetching community comments and reviews across any provider.
abstract class CommentsRepository {
  /// Fetches comments or reviews based on the polymorphic [request].
  Future<List<Comment>> fetchComments(CommentsRequest request, {int page = 1});

  /// Fetches nested replies for a specific comment.
  Future<List<Comment>> fetchReplies(
    String commentId, {
    CommentSource source = CommentSource.serializd,
  });
}
