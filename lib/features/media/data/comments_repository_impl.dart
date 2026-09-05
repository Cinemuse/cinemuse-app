import 'package:cinemuse_app/features/media/data/letterboxd_service.dart';
import 'package:cinemuse_app/features/media/data/serializd_service.dart';
import 'package:cinemuse_app/features/media/domain/comment.dart';
import 'package:cinemuse_app/features/media/domain/comments_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';

/// Implementation of [CommentsRepository] routing requests to appropriate providers.
class CommentsRepositoryImpl implements CommentsRepository {
  final SerializdService _serializdService;
  final LetterboxdService _letterboxdService;

  CommentsRepositoryImpl(
    this._serializdService,
    this._letterboxdService,
  );

  @override
  Future<List<Comment>> fetchComments(
    CommentsRequest request, {
    int page = 1,
  }) async {
    if (request is EpisodeCommentsRequest) {
      return _fetchSerializdEpisodeComments(request, page: page);
    } else if (request is MediaReviewsRequest) {
      return _fetchMediaReviews(request, page: page);
    }
    return [];
  }

  Future<List<Comment>> _fetchMediaReviews(
    MediaReviewsRequest request, {
    int page = 1,
  }) async {
    final futures = <Future<List<Comment>>>[];

    if (request.mediaType == MediaKind.tv) {
      // Serializd show-level reviews
      futures.add(_fetchSerializdShowReviews(request.tmdbId, page: page));
    } else if (request.mediaType == MediaKind.movie) {
      // Letterboxd movie reviews
      futures.add(
        _letterboxdService.fetchMovieReviews(
          tmdbId: request.tmdbId,
          imdbId: request.imdbId,
          title: request.title,
          year: request.year,
          page: page,
        ),
      );
    }

    final results = await Future.wait(futures);
    final merged = <Comment>[];
    for (final list in results) {
      merged.addAll(list);
    }
    return merged;
  }

  Future<List<Comment>> _fetchSerializdShowReviews(
    int showId, {
    int page = 1,
  }) async {
    final data = await _serializdService.fetchShowReviews(
      showId: showId,
      page: page,
    );
    final rawReviews = (data['reviews'] ?? data['items']) as List<dynamic>? ?? [];

    return rawReviews
        .whereType<Map<String, dynamic>>()
        .map(_mapSerializdReviewToComment)
        .toList();
  }

  @override
  Future<List<Comment>> fetchReplies(
    String commentId, {
    CommentSource source = CommentSource.serializd,
  }) async {
    if (source == CommentSource.serializd) {
      final rawReplies = await _serializdService.fetchReviewComments(commentId);
      return rawReplies.map(_mapSerializdReplyToComment).toList();
    }
    return [];
  }

  Future<List<Comment>> _fetchSerializdEpisodeComments(
    EpisodeCommentsRequest request, {
    int page = 1,
  }) async {
    final data = await _serializdService.fetchEpisodeReviews(
      showId: request.tmdbShowId,
      seasonNumber: request.seasonNumber,
      episodeNumber: request.episodeNumber,
      seasonId: request.seasonId,
      page: page,
    );

    final rawReviews = (data['reviews'] ?? data['items']) as List<dynamic>? ?? [];

    return rawReviews
        .whereType<Map<String, dynamic>>()
        .map(_mapSerializdReviewToComment)
        .toList();
  }

  Comment _mapSerializdReviewToComment(Map<String, dynamic> json) {
    final authorName = json['author']?.toString() ?? 'User';
    final avatar = json['authorImageUrl']?.toString();

    final author = CommentAuthor(
      id: authorName,
      username: authorName,
      avatarUrl: _cleanUrl(avatar),
    );

    return Comment(
      id: json['id']?.toString() ?? '',
      author: author,
      text: (json['reviewText']?.toString() ?? '').trim(),
      rating: _parseRating(json['rating']),
      createdAt: _parseDate(json['dateAdded']?.toString() ?? json['backdate']?.toString()),
      likeCount: _parseInt(json['likeCount'] ?? json['numLikes']),
      replyCount: _parseInt(json['numComments']),
      isSpoiler: json['containsSpoiler'] == true,
      source: CommentSource.serializd,
    );
  }

  Comment _mapSerializdReplyToComment(Map<String, dynamic> json) {
    final authorName = json['author']?.toString() ?? 'User';
    final avatar = json['authorImageUrl']?.toString();

    final author = CommentAuthor(
      id: authorName,
      username: authorName,
      avatarUrl: _cleanUrl(avatar),
    );

    return Comment(
      id: json['id']?.toString() ?? '',
      author: author,
      text: (json['commentText']?.toString() ?? '').trim(),
      createdAt: _parseDate(json['dateAdded']?.toString()),
      likeCount: _parseInt(json['numLikes']),
      isSpoiler: false,
      source: CommentSource.serializd,
    );
  }

  static double? _parseRating(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static String? _cleanUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }
}
