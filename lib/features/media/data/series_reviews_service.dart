import 'package:cinemuse_app/core/data/server_addresses_model.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:dio/dio.dart';
import 'package:cinemuse_app/features/media/data/review_json_fields.dart';

/// Series reviews, from the review site's API.
/// Failures are thrown as an [AppFailure] (REV-189).
class SeriesReviewsService {
  final Dio _dio;

  /// The API's address comes from the server's list (STR-08).
  final ServerAddressesLoader _loadAddresses;

  final Map<String, int> _seasonIdCache = {};

  /// Where the batch after each one starts, by review list and batch number.
  final Map<String, (Object, Object)> _nextBatchStarts = {};

  SeriesReviewsService(this._dio, this._loadAddresses);

  /// Resolves the site's internal `seasonId` for a given TMDB [showId] and [seasonNumber].
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
        'SeriesReviewsService',
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
    int page = 1,
  }) async {
    final resolvedSeasonId =
        seasonId ?? await resolveSeasonId(showId, seasonNumber);

    return _fetchReviewsPage(
      showId: showId,
      listKey: '$showId:$seasonNumber:$episodeNumber:$sortBy',
      page: page,
      query: {
        'sort_by': sortBy,
        'episode_number': episodeNumber,
        'include_episode_reviews': true,
        'season_id': ?resolvedSeasonId,
      },
    );
  }

  /// Fetches top-level show reviews/discussions.
  Future<Map<String, dynamic>> fetchShowReviews({
    required int showId,
    String sortBy = 'like_desc',
    int page = 1,
  }) {
    return _fetchReviewsPage(
      showId: showId,
      listKey: '$showId:$sortBy',
      page: page,
      query: {'sort_by': sortBy},
    );
  }

  /// One batch of a review list. The API has no page numbers: every answer
  /// says where the next batch starts, in two values sent back with the next
  /// request. So [page] 2 can only follow page 1.
  Future<Map<String, dynamic>> _fetchReviewsPage({
    required int showId,
    required String listKey,
    required int page,
    required Map<String, dynamic> query,
  }) async {
    final (Object, Object)? start;
    if (page > 1) {
      start = _nextBatchStarts['$listKey:${page - 1}'];
      // The list has ended, or the previous batch failed: asking without a
      // position would download the first batch again.
      if (start == null) return {};
    } else {
      start = null;
    }

    final data = await _get(
      '/show/$showId/reviewspage_v3',
      query: {
        ...query,
        if (start != null) ...{
          'cursor': start.$1,
          'secondary_cursor': start.$2,
        },
      },
    );

    final next = data?['nextCursor'];
    final secondaryNext = data?['secondaryNextCursor'];
    if (next != null && secondaryNext != null) {
      _nextBatchStarts['$listKey:$page'] = (
        next as Object,
        secondaryNext as Object,
      );
    } else {
      _nextBatchStarts.remove('$listKey:$page');
    }
    return data ?? {};
  }

  /// Fetches threaded comments/replies for a specific review [reviewId].
  Future<List<Map<String, dynamic>>> fetchReviewComments(
    String reviewId,
  ) async {
    final data = await _get('/review/$reviewId/comments');
    final comments = data?['reviewComments'] as List<dynamic>? ?? [];
    return comments.whereType<Map<String, dynamic>>().toList();
  }

  /// GET on the site's API. Throws an [AppFailure].
  Future<Map<String, dynamic>?> _get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final addresses = await _loadAddresses();
    final baseUrl = addresses.baseUrl(ServerAddress.reviews);
    if (baseUrl == null) {
      throw const NotFoundFailure('No series reviews address in the list');
    }
    // The API answers only requests that say they come from its own
    // website, a word made of the site's name.
    final site = addresses.name(ServerAddress.reviews).toLowerCase();
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$baseUrl$path',
        queryParameters: query,
        options: Options(headers: {'X-Requested-With': '${site}_vercel'}),
      );
      return response.data;
    } on DioException catch (e, st) {
      final status = e.response?.statusCode;
      final message =
          'Series reviews GET $path failed (${e.type.name}, $status)';
      throw e.type == DioExceptionType.badResponse
          ? ServerFailure(message, statusCode: status, cause: e, stackTrace: st)
          : NetworkFailure(message, cause: e, stackTrace: st);
    }
  }
}
