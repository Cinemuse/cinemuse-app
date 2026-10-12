import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:dio/dio.dart';
import 'package:cinemuse_app/features/media/data/review_json_fields.dart';

/// Service responsible for communicating with Serializd API endpoints.
/// Failures are thrown as an [AppFailure] (REV-189).
class SerializdService {
  static const String _baseUrl = 'https://serializd.onrender.com/api';
  static const Map<String, String> _defaultHeaders = {
    'X-Requested-With': 'serializd_vercel',
    'Referer': 'https://www.serializd.com',
  };

  final Dio _dio;
  final Map<String, int> _seasonIdCache = {};

  SerializdService(this._dio);

  /// Resolves the internal Serializd `seasonId` for a given TMDB [showId] and [seasonNumber].
  ///
  /// Caches the result in-memory to avoid redundant HTTP requests.
  Future<int?> resolveSeasonId(int showId, int seasonNumber) async {
    final cacheKey = '$showId:$seasonNumber';
    if (_seasonIdCache.containsKey(cacheKey)) {
      return _seasonIdCache[cacheKey];
    }

    try {
      final data = await _get('/show/$showId/season/$seasonNumber');
      if (data != null && data['seasonId'] != null) {
        final seasonId = jsonInt(data['seasonId']);
        if (seasonId > 0) {
          _seasonIdCache[cacheKey] = seasonId;
          return seasonId;
        }
      }
    } on AppFailure catch (e, st) {
      // Safe to go on: the reviews request works without a season id.
      AppLogger.warn(
        'SerializdService',
        'No seasonId for show $showId season $seasonNumber',
        error: e,
        stackTrace: st,
      );
    }
    return null;
  }

  /// Fetches reviews/comments for a specific episode.
  ///
  /// [showId] is the TMDB show ID.
  /// If [seasonId] is omitted, it will automatically be resolved via [resolveSeasonId].
  Future<Map<String, dynamic>> fetchEpisodeReviews({
    required int showId,
    required int seasonNumber,
    required int episodeNumber,
    int? seasonId,
    String sortBy = 'like_desc',
    String? cursor,
    int page = 1,
  }) async {
    final resolvedSeasonId =
        seasonId ?? await resolveSeasonId(showId, seasonNumber);

    final queryParams = <String, dynamic>{
      'sort_by': sortBy,
      'episode_number': episodeNumber,
      'include_episode_reviews': true,
      'page': page,
    };

    if (resolvedSeasonId != null) {
      queryParams['season_id'] = resolvedSeasonId;
    }

    if (cursor != null && cursor.isNotEmpty) {
      queryParams['cursor'] = cursor;
    }

    return await _get('/show/$showId/reviewspage_v3', query: queryParams) ?? {};
  }

  /// Fetches top-level show reviews/discussions.
  Future<Map<String, dynamic>> fetchShowReviews({
    required int showId,
    String sortBy = 'like_desc',
    String? cursor,
    int page = 1,
  }) async {
    final queryParams = <String, dynamic>{'sort_by': sortBy, 'page': page};

    if (cursor != null && cursor.isNotEmpty) {
      queryParams['cursor'] = cursor;
    }

    return await _get('/show/$showId/reviewspage_v3', query: queryParams) ?? {};
  }

  /// Fetches threaded comments/replies for a specific review [reviewId].
  Future<List<Map<String, dynamic>>> fetchReviewComments(
    String reviewId,
  ) async {
    final data = await _get('/review/$reviewId/comments');
    final comments = data?['reviewComments'] as List<dynamic>? ?? [];
    return comments.whereType<Map<String, dynamic>>().toList();
  }

  /// GET on the Serializd API. Throws an [AppFailure].
  Future<Map<String, dynamic>?> _get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl$path',
        queryParameters: query,
        options: Options(headers: _defaultHeaders),
      );
      return response.data;
    } on DioException catch (e, st) {
      final status = e.response?.statusCode;
      final message = 'Serializd GET $path failed (${e.type.name}, $status)';
      throw e.type == DioExceptionType.badResponse
          ? ServerFailure(message, statusCode: status, cause: e, stackTrace: st)
          : NetworkFailure(message, cause: e, stackTrace: st);
    }
  }
}
