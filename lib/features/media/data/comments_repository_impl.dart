import 'dart:developer' as developer;
import 'package:cinemuse_app/core/services/media/tmdb_service.dart';
import 'package:cinemuse_app/features/media/data/imdb_service.dart';
import 'package:cinemuse_app/features/media/data/letterboxd_service.dart';
import 'package:cinemuse_app/features/media/data/serializd_service.dart';
import 'package:cinemuse_app/features/media/domain/comment.dart';
import 'package:cinemuse_app/features/media/domain/comments_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';

/// Implementation of [CommentsRepository] routing requests to appropriate providers.
class CommentsRepositoryImpl implements CommentsRepository {
  final SerializdService _serializdService;
  final LetterboxdService _letterboxdService;
  final ImdbService _imdbService;
  final TmdbService _tmdbService;

  CommentsRepositoryImpl(
    this._serializdService,
    this._letterboxdService,
    this._imdbService,
    this._tmdbService,
  );

  @override
  Future<List<Comment>> fetchComments(
    CommentsRequest request, {
    int page = 1,
  }) async {
    if (request is EpisodeCommentsRequest) {
      return _fetchEpisodeComments(request, page: page);
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
      futures.add(_safeFetch(() => _fetchSerializdShowReviews(request.tmdbId, page: page)));
    } else if (request.mediaType == MediaKind.movie) {
      futures.add(
        _safeFetch(
          () => _letterboxdService.fetchMovieReviews(
            tmdbId: request.tmdbId,
            imdbId: request.imdbId,
            title: request.title,
            year: request.year,
            page: page,
          ),
        ),
      );
    }

    // Fetch IMDb reviews for top-level media
    futures.add(_safeFetch(() => _fetchTopLevelImdbReviews(request, page: page)));

    final results = await Future.wait(futures);
    return _interleaveComments(results);
  }

  Future<List<Comment>> _fetchTopLevelImdbReviews(
    MediaReviewsRequest request, {
    int page = 1,
  }) async {
    // Only fetch first batch or paginated from IMDb
    final imdbId = request.imdbId ??
        await _tmdbService.getImdbId(
          request.tmdbId,
          request.mediaType == MediaKind.movie ? 'movie' : 'tv',
        );

    if (imdbId == null || imdbId.isEmpty) return const [];

    return _imdbService.fetchReviews(
      imdbId: imdbId,
      limit: 10,
      page: page,
    );
  }

  Future<List<Comment>> _fetchEpisodeComments(
    EpisodeCommentsRequest request, {
    int page = 1,
  }) async {
    final futures = <Future<List<Comment>>>[
      _safeFetch(() => _fetchSerializdEpisodeReviews(request, page: page)),
      _safeFetch(() => _fetchEpisodeImdbReviews(request, page: page)),
    ];

    final results = await Future.wait(futures);
    return _interleaveComments(results);
  }

  Future<List<Comment>> _fetchSerializdEpisodeReviews(
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

  Future<List<Comment>> _fetchEpisodeImdbReviews(
    EpisodeCommentsRequest request, {
    int page = 1,
  }) async {
    final episodeImdbId = request.imdbId ??
        await _tmdbService.getEpisodeImdbId(
          request.tmdbShowId,
          request.seasonNumber,
          request.episodeNumber,
        );

    if (episodeImdbId == null || episodeImdbId.isEmpty) return const [];

    return _imdbService.fetchReviews(
      imdbId: episodeImdbId,
      limit: 10,
      page: page,
    );
  }

  List<Comment> _interleaveComments(List<List<Comment>> lists) {
    final activeLists = lists.where((l) => l.isNotEmpty).toList();
    if (activeLists.isEmpty) return const [];
    if (activeLists.length == 1) return activeLists.first;

    final result = <Comment>[];
    int index = 0;
    bool hasMore = true;

    while (hasMore) {
      hasMore = false;
      for (final list in activeLists) {
        if (index < list.length) {
          result.add(list[index]);
          hasMore = true;
        }
      }
      index++;
    }

    return result;
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

  Future<List<Comment>> _safeFetch(Future<List<Comment>> Function() fetcher) async {
    try {
      return await fetcher();
    } catch (e, stack) {
      developer.log(
        'Comments provider fetch failure',
        name: 'CommentsRepositoryImpl',
        error: e,
        stackTrace: stack,
      );
      return const [];
    }
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
