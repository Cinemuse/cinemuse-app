import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final tmdbServiceProvider = Provider<TmdbService>((ref) {
  return TmdbService(ref.read(dioProvider));
});

class TmdbService {
  final Dio _dio;
  final String _baseUrl = 'https://api.themoviedb.org/3';

  TmdbService(this._dio);

  String get _apiKey => dotenv.env['TMDB_API_KEY'] ?? '';

  Future<Map<String, dynamic>?> getMediaDetails(String id, String type) async {
    try {
      // Normalize type (tmdb uses 'tv' for series)
      final normalizedType = (type == 'series' || type == 'tv') ? 'tv' : 'movie';
      
      // Handle IMDB ID conversion if needed
      String tmdbId = id;
      if (id.startsWith('tt')) {
         final findRes = await _dio.get(
          '$_baseUrl/find/$id',
          queryParameters: {'api_key': _apiKey, 'external_source': 'imdb_id'},
        );
        final data = findRes.data;
        if (normalizedType == 'movie' && data['movie_results'].isNotEmpty) {
           tmdbId = data['movie_results'][0]['id'].toString();
        } else if (normalizedType == 'tv' && data['tv_results'].isNotEmpty) {
           tmdbId = data['tv_results'][0]['id'].toString();
        } else {
           return null;
        }
      }

      final res = await _dio.get(
        '$_baseUrl/$normalizedType/$tmdbId',
        queryParameters: {
          'api_key': _apiKey, 
          'language': 'en-US',
          'append_to_response': 'credits,videos,similar,recommendations,external_ids'
        },
      );
      return res.data;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getSeasonDetails(int tmdbId, int seasonNumber) async {
    try {
      final res = await _dio.get(
        '$_baseUrl/tv/$tmdbId/season/$seasonNumber',
         queryParameters: {
          'api_key': _apiKey, 
          'language': 'en-US',
        },
      );
      return res.data;
    } catch (e) {
      return null;
    }
  }

  Future<String?> getImdbId(int tmdbId, String type) async {
     final endpoint = type == 'movie' ? 'movie' : 'tv';
    try {
      final res = await _dio.get(
        '$_baseUrl/$endpoint/$tmdbId/external_ids',
        queryParameters: {'api_key': _apiKey},
      );
      return res.data['imdb_id'] as String?;
    } catch (e) {
      return null;
    }
  }
  
  // Trending & Popular
  Future<List<Map<String, dynamic>>> getTrending() async {
     try {
      final res = await _dio.get(
        '$_baseUrl/trending/all/week',
        queryParameters: {'api_key': _apiKey, 'language': 'en-US'},
      );
      return List<Map<String, dynamic>>.from(res.data['results']);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPopularMovies() async {
    try {
      final res = await _dio.get(
        '$_baseUrl/movie/popular',
        queryParameters: {'api_key': _apiKey, 'language': 'en-US'},
      );
      final results = List<Map<String, dynamic>>.from(res.data['results']);
      return results.map((item) => {...item, 'media_type': 'movie'}).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPopularSeries() async {
    try {
      final res = await _dio.get(
        '$_baseUrl/tv/popular',
        queryParameters: {'api_key': _apiKey, 'language': 'en-US'},
      );
      final results = List<Map<String, dynamic>>.from(res.data['results']);
      return results.map((item) => {...item, 'media_type': 'tv'}).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchMulti(String query, {int page = 1}) async {
    try {
      if (query.isEmpty) return [];
      final res = await _dio.get(
        '$_baseUrl/search/multi',
        queryParameters: {
          'api_key': _apiKey, 
          'language': 'en-US',
          'query': query,
          'include_adult': false,
          'page': page,
        },
      );
      // Filter out 'person' results for now
      final results = List<Map<String, dynamic>>.from(res.data['results']);
      return results;
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> discover({
    required String type,
    required int page,
    String? sortBy,
    List<int>? genres,
    List<String>? languages,
    double? minRating,
    double? maxRating,
    int? minYear,
    int? maxYear,
    int? minVotes,
    int? maxVotes,
    int? minRuntime,
    int? maxRuntime,
  }) async {
    try {
      final queryParams = {
        'api_key': _apiKey,
        'page': page,
        'language': 'en-US',
        'include_adult': false,
        'sort_by': sortBy ?? 'popularity.desc',
      };

      if (genres != null && genres.isNotEmpty) {
        queryParams['with_genres'] = genres.join(',');
      }
      if (languages != null && languages.isNotEmpty) {
        queryParams['with_original_language'] = languages.join('|');
      }
      if (minRating != null) queryParams['vote_average.gte'] = minRating;
      if (maxRating != null) queryParams['vote_average.lte'] = maxRating;
      if (minVotes != null) queryParams['vote_count.gte'] = minVotes;
      if (maxVotes != null) queryParams['vote_count.lte'] = maxVotes;
      if (minRuntime != null) queryParams['with_runtime.gte'] = minRuntime;
      if (maxRuntime != null) queryParams['with_runtime.lte'] = maxRuntime;

      final dateField = type == 'movie' ? 'primary_release_date' : 'first_air_date';
      if (minYear != null) queryParams['$dateField.gte'] = '$minYear-01-01';
      if (maxYear != null) queryParams['$dateField.lte'] = '$maxYear-12-31';

      final res = await _dio.get(
        '$_baseUrl/discover/$type',
        queryParameters: queryParams,
      );
      return res.data;
    } catch (e) {
      return {'results': [], 'total_pages': 0};
    }
  }

  Future<Map<String, dynamic>?> getPersonDetails(int id) async {
    try {
      final res = await _dio.get(
        '$_baseUrl/person/$id',
        queryParameters: {
          'api_key': _apiKey,
          'language': 'en-US',
          'append_to_response': 'combined_credits,external_ids,images',
        },
      );
      return res.data;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> getPopularPersons(int page) async {
    try {
      final res = await _dio.get(
        '$_baseUrl/person/popular',
        queryParameters: {
          'api_key': _apiKey,
          'page': page,
          'language': 'en-US',
        },
      );
      return res.data;
    } catch (e) {
      return {'results': [], 'total_pages': 0};
    }
  }

  /// Helper to check if a media item is an anime.
  static bool isAnime(Map<String, dynamic> details) {
    try {
      final genres = details['genres'] as List?;
      final isAnimation = genres?.any((g) {
            if (g is Map) return g['id'] == 16;
            if (g is int) return g == 16;
            return false;
          }) ??
          false;

      final originalLanguage = details['original_language'] as String?;
      final originCountry = details['origin_country'] as List?;

      return isAnimation && (originalLanguage == 'ja' || (originCountry?.contains('JP') ?? false));
    } catch (e) {
      return false;
    }
  }
}
