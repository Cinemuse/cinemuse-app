import 'dart:developer' as developer;
import 'package:dio/dio.dart';

/// Service responsible for communicating with Serializd API endpoints.
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
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/show/$showId/season/$seasonNumber',
        options: Options(headers: _defaultHeaders),
      );

      final data = response.data;
      if (data != null && data['seasonId'] != null) {
        final seasonId = _parseInt(data['seasonId']);
        if (seasonId > 0) {
          _seasonIdCache[cacheKey] = seasonId;
          return seasonId;
        }
      }
    } catch (e, stack) {
      developer.log(
        'Failed to resolve Serializd seasonId for show $showId season $seasonNumber',
        name: 'SerializdService',
        error: e,
        stackTrace: stack,
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
    final resolvedSeasonId = seasonId ?? await resolveSeasonId(showId, seasonNumber);

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

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/show/$showId/reviewspage_v3',
        queryParameters: queryParams,
        options: Options(headers: _defaultHeaders),
      );

      return response.data ?? {};
    } catch (e, stack) {
      developer.log(
        'Failed to fetch Serializd episode reviews for show $showId season $seasonNumber episode $episodeNumber',
        name: 'SerializdService',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Fetches top-level show reviews/discussions.
  Future<Map<String, dynamic>> fetchShowReviews({
    required int showId,
    String sortBy = 'like_desc',
    String? cursor,
    int page = 1,
  }) async {
    final queryParams = <String, dynamic>{
      'sort_by': sortBy,
      'page': page,
    };

    if (cursor != null && cursor.isNotEmpty) {
      queryParams['cursor'] = cursor;
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/show/$showId/reviewspage_v3',
        queryParameters: queryParams,
        options: Options(headers: _defaultHeaders),
      );

      return response.data ?? {};
    } catch (e, stack) {
      developer.log(
        'Failed to fetch Serializd show reviews for show $showId',
        name: 'SerializdService',
        error: e,
        stackTrace: stack,
      );
      return {};
    }
  }

  /// Fetches threaded comments/replies for a specific review [reviewId].
  Future<List<Map<String, dynamic>>> fetchReviewComments(String reviewId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/review/$reviewId/comments',
        options: Options(headers: _defaultHeaders),
      );

      final data = response.data;
      if (data == null) return [];

      final comments = data['reviewComments'] as List<dynamic>? ?? [];
      return comments.whereType<Map<String, dynamic>>().toList();
    } catch (e, stack) {
      developer.log(
        'Failed to fetch review comments for review $reviewId',
        name: 'SerializdService',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }
}
