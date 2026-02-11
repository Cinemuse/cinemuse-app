
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// TODO: Move to a config file or env
const String tmdbApiKey = '32a33723c01e47809f0325026ecf01b1'; 
const String rdApiUrl = "https://api.real-debrid.com/rest/1.0";

final streamResolverProvider = Provider((ref) => StreamResolver(Dio()));

class StreamResolver {
  final Dio _dio;

  StreamResolver(this._dio);

  /// Main entry point to get a stream URL
  /// Search for available streams (torrents)
  Future<List<Map<String, dynamic>>> searchStreams(
    String queryId, // Can be TMDB ID (digits) or IMDB ID (tt...)
    String type,
    String rdKey, {
    int? season,
    int? episode,
  }) async {
    try {
      String? imdbId;

      // 1. Detect ID type
      if (queryId.startsWith('tt')) {
        imdbId = queryId;
      } else {
        // Assume TMDB ID
        final tmdbId = int.tryParse(queryId);
        if (tmdbId == null) throw Exception("Invalid ID format");
        imdbId = await _getImdbId(tmdbId, type);
      }

      if (imdbId == null) throw Exception("Could not resolve IMDB ID");

      // 2. Search Torrents
      var torrents = await _searchStreams(imdbId, type, season, episode);
      if (torrents.isEmpty) return [];

      // 3. Mark Cached Status
      // OPTIMIZATION: Check for cached torrents (top 15)
      try {
        final hashes = torrents.take(15).map((t) => t['infoHash'] as String).toList();
        if (hashes.isNotEmpty) {
          final availableHashes = await _checkInstantAvailability(hashes, rdKey);
          
          for (var t in torrents) {
            if (availableHashes.contains((t['infoHash'] as String).toLowerCase())) {
              t['cached'] = true;
            } else {
              t['cached'] = false;
            }
          }

          // Re-sort to put cached first
          torrents.sort((a, b) {
            final aCached = (a['cached'] == true) ? 1 : 0;
            final bCached = (b['cached'] == true) ? 1 : 0;
            return bCached - aCached;
          });
        }
      } catch (e) {
        // Ignore optimization error
      }

      return torrents;
    } catch (e) {
      rethrow;
    }
  }

  /// Resolve a specific magnet link to a direct stream URL
  Future<Map<String, dynamic>?> resolveStream(String magnet, String rdKey) async {
    return _resolveRealDebrid(magnet, rdKey);
  }

  Future<String?> _getImdbId(int tmdbId, String type) async {
    final endpoint = type == 'movie' ? 'movie' : 'tv';
    try {
      final res = await _dio.get(
        'https://api.themoviedb.org/3/$endpoint/$tmdbId/external_ids',
        queryParameters: {'api_key': tmdbApiKey},
      );
      return res.data['imdb_id'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Fetch Trending Movies/TV
  Future<List<Map<String, dynamic>>> getTrending() async {
    try {
      final res = await _dio.get(
        'https://api.themoviedb.org/3/trending/all/week',
        queryParameters: {'api_key': tmdbApiKey, 'language': 'en-US'},
      );
      return List<Map<String, dynamic>>.from(res.data['results']);
    } catch (e) {
      return [];
    }
  }

  /// Fetch Popular Movies
  Future<List<Map<String, dynamic>>> getPopularMovies() async {
    try {
      final res = await _dio.get(
        'https://api.themoviedb.org/3/movie/popular',
        queryParameters: {'api_key': tmdbApiKey, 'language': 'en-US'},
      );
      return List<Map<String, dynamic>>.from(res.data['results']);
    } catch (e) {
      return [];
    }
  }

  /// Fetch Popular Series
  Future<List<Map<String, dynamic>>> getPopularSeries() async {
    try {
      final res = await _dio.get(
        'https://api.themoviedb.org/3/tv/popular',
        queryParameters: {'api_key': tmdbApiKey, 'language': 'en-US'},
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
        'https://api.themoviedb.org/3/search/multi',
        queryParameters: {
          'api_key': tmdbApiKey, 
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

  /// Get Media Details (Movie/TV)
  Future<Map<String, dynamic>?> getMediaDetails(String id, String type) async {
    try {
      // If IMDB ID, find TMDB ID first (or just search find)
      String tmdbId = id;
      if (id.startsWith('tt')) {
         final findRes = await _dio.get(
          'https://api.themoviedb.org/3/find/$id',
          queryParameters: {'api_key': tmdbApiKey, 'external_source': 'imdb_id'},
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
        'https://api.themoviedb.org/3/$type/$tmdbId',
        queryParameters: {'api_key': tmdbApiKey, 'language': 'en-US'},
      );
      return res.data;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _searchStreams(
    String imdbId,
    String type,
    int? season,
    int? episode,
  ) async {
    String queryId = imdbId;
    if (type == 'tv' && season != null && episode != null) {
      queryId = "$imdbId:$season:$episode";
    }

    // 1. Try Torrentio
    try {
      final url = "https://torrentio.strem.fun/stream/$type/$queryId.json";
      final res = await _dio.get(url);
      if (res.statusCode == 200 && res.data['streams'] != null) {
        final streamsData = res.data['streams'] as List;
        final streams = streamsData.map((s) {
          return {
            'title': (s['title'] ?? "").replaceAll('\n', " "),
            'infoHash': s['infoHash'],
            'magnet': "magnet:?xt=urn:btih:${s['infoHash']}&dn=${Uri.encodeComponent(s['title'] ?? "")}",
            'seeds': s['seeds'] ?? 0,
          };
        }).toList();

        // Sort logic
        streams.sort((a, b) {
          int score(Map<String, dynamic> str) {
            int s = 0;
            final t = (str['title'] as String).toLowerCase();
            if (t.contains('ita') || t.contains('italian')) s += 50;
            if (t.contains('multi')) s += 20;
            if (t.contains('eng') || t.contains('english')) s += 5;
            if (t.contains('aac')) s += 10;
            if (t.contains('x265') || t.contains('h265') || t.contains('hevc')) s += 2;
            if (t.contains('x264') || t.contains('h264')) s += 3;
            if (t.contains('1080p')) s += 2;
            if (t.contains('7.1') || t.contains('truehd') || t.contains('dts')) s -= 5;
            return s;
          }
          return score(b) - score(a);
        });
        return streams.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      // Ignore
    }

    // 2. Try YTS (Movies only) - Fallback
    if (type == 'movie') {
      try {
        final url = "https://yts.mx/api/v2/list_movies.json?query_term=$imdbId";
        final res = await _dio.get(url);
        final data = res.data;
        if (data['status'] == 'ok' && data['data']['movies'] != null) {
          final movies = data['data']['movies'] as List;
          if (movies.isNotEmpty) {
            final movie = movies[0];
            if (movie['torrents'] != null) {
              final torrents = (movie['torrents'] as List).map((t) => {
                'title': "${movie['title']} ${movie['year']} ${t['quality']} ${t['type']}",
                'infoHash': t['hash'],
                'magnet': "magnet:?xt=urn:btih:${t['hash']}&dn=${Uri.encodeComponent(movie['title'])}&tr=udp://open.demonii.com:1337/announce",
                'seeds': t['seeds'] ?? 0,
              }).toList();
              
              torrents.sort((a, b) {
                 if (b['seeds'] != a['seeds']) return (b['seeds'] as int) - (a['seeds'] as int);
                 return 0;
              });

              return torrents.cast<Map<String, dynamic>>();
            }
          }
        }
      } catch (e) {
        // Ignore
      }
    }

    return [];
  }

  Future<Map<String, dynamic>?> _resolveRealDebrid(String magnet, String apiKey) async {
    final headers = { "Authorization": "Bearer $apiKey" };

    final addFormData = FormData.fromMap({ "magnet": magnet });
    final addRes = await _dio.post(
      "$rdApiUrl/torrents/addMagnet",
      data: addFormData,
      options: Options(headers: headers),
    );

    final torrentId = addRes.data['id'];

    final infoRes = await _dio.get(
      "$rdApiUrl/torrents/info/$torrentId",
      options: Options(headers: headers),
    );
    var info = infoRes.data;

    if (info['status'] == 'waiting_files_selection') {
      final files = info['files'] as List;
      final videoFiles = files.where((f) {
        final path = (f['path'] as String).toLowerCase();
        return path.endsWith('.mp4') || path.endsWith('.mkv') || path.endsWith('.avi') || 
               path.endsWith('.mov') || path.endsWith('.m4v') || path.endsWith('.webm') ||
               path.endsWith('.flv') || path.endsWith('.wmv');
      }).toList();

      videoFiles.sort((a, b) => (b['bytes'] as int) - (a['bytes'] as int));

      if (videoFiles.isEmpty) throw Exception("No video files found in torrent");

      final fileId = videoFiles[0]['id'];

      final selFormData = FormData.fromMap({ "files": fileId.toString() });

      await _dio.post(
        "$rdApiUrl/torrents/selectFiles/$torrentId",
        data: selFormData,
        options: Options(headers: headers),
      );

       final infoRes2 = await _dio.get(
        "$rdApiUrl/torrents/info/$torrentId",
        options: Options(headers: headers),
      );
      info = infoRes2.data;
    }

    if (info['links'] != null && (info['links'] as List).isNotEmpty) {
      final link = info['links'][0];
      final unrestrictFormData = FormData.fromMap({ "link": link });

      final unrestrictRes = await _dio.post(
        "$rdApiUrl/unrestrict/link",
        data: unrestrictFormData,
        options: Options(headers: headers),
      );

      final unrestrictData = unrestrictRes.data;
      final finalUrl = unrestrictData['download'];

      if (finalUrl.toString().toLowerCase().contains('.rar')) {
         throw Exception("Resolved URL is an archive (RAR/ZIP), skipping.");
      }

      return {
        'url': finalUrl,
        'mimeType': unrestrictData['mimeType'],
        'filename': unrestrictData['filename'],
        'originalUrl': finalUrl,
      };
    }

    return null;
  }
  
  Future<List<String>> _checkInstantAvailability(List<String> hashes, String apiKey) async {
    if (hashes.isEmpty) return [];
    
    final headers = { "Authorization": "Bearer $apiKey" };
    final hashPath = hashes.join('/');
    
    try {
      final res = await _dio.get(
        "$rdApiUrl/torrents/instantAvailability/$hashPath",
        options: Options(headers: headers),
      );
      
      final data = res.data as Map<String, dynamic>;
      final available = <String>[];
      
      data.forEach((hash, variants) {
        if (variants is Map && variants['rd'] != null && (variants['rd'] as List).isNotEmpty) {
           available.add(hash.toLowerCase());
        }
      });
      return available;
    } catch (e) {
      return [];
    }
  }

}
