import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final tmdbServiceProvider = Provider<TmdbService>((ref) {
  return TmdbService(Dio());
});

class TmdbService {
  final Dio _dio;
  final String _baseUrl = 'https://api.themoviedb.org/3';

  TmdbService(this._dio);

  String get _apiKey => dotenv.env['TMDB_API_KEY'] ?? '';

  Future<Map<String, dynamic>?> getMediaDetails(String id, String type) async {
    try {
      // Handle IMDB ID conversion if needed
      String tmdbId = id;
      if (id.startsWith('tt')) {
         final findRes = await _dio.get(
          '$_baseUrl/find/$id',
          queryParameters: {'api_key': _apiKey, 'external_source': 'imdb_id'},
        );
        final data = findRes.data;
        if (type == 'movie' && data['movie_results'].isNotEmpty) {
           tmdbId = data['movie_results'][0]['id'].toString();
        } else if (type == 'tv' && data['tv_results'].isNotEmpty) {
           tmdbId = data['tv_results'][0]['id'].toString();
        } else {
           return null;
        }
      }

      final res = await _dio.get(
        '$_baseUrl/$type/$tmdbId',
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
      return List<Map<String, dynamic>>.from(res.data['results']);
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
      return List<Map<String, dynamic>>.from(res.data['results']);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchMulti(String query) async {
    try {
      if (query.isEmpty) return [];
      final res = await _dio.get(
        '$_baseUrl/search/multi',
        queryParameters: {
          'api_key': _apiKey, 
          'language': 'en-US',
          'query': query,
          'include_adult': false,
        },
      );
      // Filter out 'person' results for now
      final results = List<Map<String, dynamic>>.from(res.data['results']);
      return results.where((item) => item['media_type'] != 'person').toList();
    } catch (e) {
      return [];
    }
  }
}
