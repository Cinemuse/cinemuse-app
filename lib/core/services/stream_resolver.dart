
import 'package:cinemuse_app/core/services/tmdb_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String rdApiUrl = "https://api.real-debrid.com/rest/1.0";

final streamResolverProvider = Provider((ref) {
  return StreamResolver(Dio(), ref.read(tmdbServiceProvider));
});

class StreamResolver {
  final Dio _dio;
  final TmdbService _tmdbService;

  StreamResolver(this._dio, this._tmdbService);

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
        imdbId = await _tmdbService.getImdbId(tmdbId, type);
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

          // Re-sort to put cached first while maintaining score order
          torrents.sort((a, b) {
            final aCached = (a['cached'] == true) ? 1 : 0;
            final bCached = (b['cached'] == true) ? 1 : 0;
            
            if (aCached != bCached) {
              return bCached - aCached;
            }
            
            // Stable sort: Use the pre-calculated score as tie-breaker
            final aScore = a['score'] as int? ?? 0;
            final bScore = b['score'] as int? ?? 0;
            return bScore - aScore;
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

  // Delegated Methods to TmdbService
  Future<List<Map<String, dynamic>>> getTrending() => _tmdbService.getTrending();
  Future<List<Map<String, dynamic>>> getPopularMovies() => _tmdbService.getPopularMovies();
  Future<List<Map<String, dynamic>>> getPopularSeries() => _tmdbService.getPopularSeries();

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

    final List<Future<List<Map<String, dynamic>>>> providerFutures = [];

    // 1. Torrentio
    providerFutures.add(_fetchTorrentio(type, queryId));

    // 2. KnightCrawler
    providerFutures.add(_fetchKnightCrawler(type, queryId));

    // 3. YTS (Movies only)
    if (type == 'movie') {
      providerFutures.add(_fetchYts(imdbId));
    }

    final results = await Future.wait(providerFutures);
    final allStreams = results.expand((x) => x).toList();

    // Deduplicate by infoHash
    final Map<String, Map<String, dynamic>> uniqueStreams = {};
    for (var stream in allStreams) {
      final hash = (stream['infoHash'] as String?)?.toLowerCase();
      if (hash != null) {
        if (!uniqueStreams.containsKey(hash)) {
          uniqueStreams[hash] = stream;
        } else {
          // Keep the one with more seeds if duplicate
          if ((stream['seeds'] ?? 0) > (uniqueStreams[hash]!['seeds'] ?? 0)) {
            uniqueStreams[hash] = stream;
          }
        }
      }
    }

    final streams = uniqueStreams.values.toList();

    // 2. Hard Exclusion (Remove CAM, 3D, Screener immediately)
    final filteredStreams = streams.where((s) {
      final t = (s['title'] as String).toLowerCase();
      return !(t.contains('cam') || 
               t.contains(' ts ') || 
               t.contains('hdcam') || 
               t.contains('screener') || 
               t.contains(' scr ') ||
               t.contains(' 3d ') ||
               t.contains('sbs'));
    }).toList();

    // 3. Score and Sort
    final List<Map<String, dynamic>> scoredStreams = filteredStreams.map((str) {
      int score(Map<String, dynamic> str) {
        int s = 0;
        final t = (str['title'] as String).toLowerCase();
        
        // Language detection
        final isItalian = t.contains('ita') || t.contains('italian') || t.contains('italy') || t.contains(RegExp(r'\bit\b')) || t.contains('🇮🇹');
        final isEnglish = t.contains('eng') || t.contains('english') || t.contains(RegExp(r'\ben\b')) || t.contains('🇬🇧') || t.contains('🇺🇸');
        final isMulti = t.contains('multi') || (isItalian && isEnglish);

        // Language prioritization
        if (isItalian) s += 100;
        if (isEnglish) s += 20;
        if (isMulti) s += 150; // Massively boost ITA+ENG / Multi

        // Negative scoring for non-preferred languages
        if (t.contains(' rus') || t.contains('.ru.') || t.contains('russian') || t.contains('lostfilm') || t.contains('hdrezka') || t.contains('syncmer')) s -= 500;
        if (t.contains(' ukr') || t.contains('ukrainian')) s -= 500;
        if (t.contains(' fra') || t.contains('french')) s -= 200;
        if (t.contains(' ger') || t.contains('german')) s -= 200;
        if (t.contains(' spa') || t.contains('spanish')) s -= 200;
        
        // Specifically penalize common Russian release groups if Italian is not present
        if (!isItalian && (t.contains('lostfilm') || t.contains('hdrezka') || t.contains('syncmer') || t.contains('newcomers'))) s -= 800;
        
        // Video quality & 10-bit
        if (t.contains('10bit') || t.contains('hevc') || t.contains('x265') || t.contains('h265')) s += 30;
        if (t.contains('hdr') || t.contains(' dv ') || t.contains('dovi')) s += 25;
        
        // Resolution & Penalization
        if (t.contains('2160p') || t.contains('4k')) s += 50;
        else if (t.contains('1080p')) s += 30;
        else if (t.contains('720p')) s += 10;
        else if (t.contains('480p')) s -= 50; // Penalize SD
        else s -= 30; // Unknown or other resolution penalty

        // Penalize "Other" types (DVDRip, HDRip, etc.)
        if (t.contains('dvdrip') || t.contains('hdrip') || t.contains('bdrip') || t.contains('dvdscr')) s -= 40;

        // Seeders impact (logarithmic-ish)
        final seeds = str['seeds'] as int? ?? 0;
        if (seeds > 100) s += 20;
        else if (seeds > 50) s += 15;
        else if (seeds > 10) s += 10;
        else if (seeds > 0) s += 5;

        // Penalize older codecs for 4K if not HEVC (rare but possible)
        if (t.contains('2160p') && !t.contains('hevc') && !t.contains('x265')) s -= 20;

        return s;
      }
      
      final s = score(str);
      return {
        ...str,
        'score': s,
        'metadata': _parseMetadata(str['title'] as String),
      };
    }).toList();

    scoredStreams.sort((a, b) {
      final aScore = a['score'] as int;
      final bScore = b['score'] as int;
      return bScore - aScore;
    });

    return scoredStreams;
  }

  Future<List<Map<String, dynamic>>> _fetchTorrentio(String type, String queryId) async {
    try {
      final url = "https://torrentio.strem.fun/stream/$type/$queryId.json";
      final res = await _dio.get(url, options: Options(receiveTimeout: const Duration(seconds: 5)));
      if (res.statusCode == 200 && res.data['streams'] != null) {
        final streamsData = res.data['streams'] as List;
        return streamsData.map((s) {
          return {
            'title': (s['title'] ?? "").replaceAll('\n', " "),
            'infoHash': s['infoHash'],
            'magnet': "magnet:?xt=urn:btih:${s['infoHash']}&dn=${Uri.encodeComponent(s['title'] ?? "")}",
            'seeds': s['seeds'] ?? 0,
            'provider': 'Torrentio',
          };
        }).toList();
      }
    } catch (e) {
      print('Torrentio fetch failed: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _fetchKnightCrawler(String type, String queryId) async {
    try {
      final url = "https://knightcrawler.elfhosted.com/stream/$type/$queryId.json";
      final res = await _dio.get(url, options: Options(
        receiveTimeout: const Duration(seconds: 5),
        responseType: ResponseType.json,
      ));
      
      final data = res.data;
      if (res.statusCode == 200 && data is Map && data['streams'] != null) {
        final streamsData = data['streams'] as List;
        return streamsData.map((s) {
          final title = (s['title'] ?? "").replaceAll('\n', " ");
          return {
            'title': title,
            'infoHash': s['infoHash'],
            'magnet': "magnet:?xt=urn:btih:${s['infoHash']}&dn=${Uri.encodeComponent(title)}",
            'seeds': s['seeds'] ?? 0,
            'provider': 'KnightCrawler',
          };
        }).toList();
      }
    } catch (e) {
       print('KnightCrawler fetch failed: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _fetchYts(String imdbId) async {
    try {
      final url = "https://yts.mx/api/v2/list_movies.json?query_term=$imdbId";
      final res = await _dio.get(url, options: Options(receiveTimeout: const Duration(seconds: 5)));
      final data = res.data;
      if (data['status'] == 'ok' && data['data']['movies'] != null) {
        final movies = data['data']['movies'] as List;
        if (movies.isNotEmpty) {
          final movie = movies[0];
          if (movie['torrents'] != null) {
            return (movie['torrents'] as List).map((t) => {
              'title': "${movie['title']} ${movie['year']} ${t['quality']} ${t['type']}",
              'infoHash': t['hash'],
              'magnet': "magnet:?xt=urn:btih:${t['hash']}&dn=${Uri.encodeComponent(movie['title'])}&tr=udp://open.demonii.com:1337/announce",
              'seeds': t['seeds'] ?? 0,
              'provider': 'YTS',
            }).toList().cast<Map<String, dynamic>>();
          }
        }
      }
    } catch (e) {
      print('YTS fetch failed: $e');
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
  
  Map<String, dynamic> _parseMetadata(String title) {
    final t = title.toLowerCase();
    
    // 1. Resolution
    String? resolution;
    if (t.contains('2160p') || t.contains('4k')) resolution = '4K';
    else if (t.contains('1080p')) resolution = '1080p';
    else if (t.contains('720p')) resolution = '720p';
    else if (t.contains('480p')) resolution = '480p';

    // 2. Quality/Source
    final List<String> qualityIndicators = [];
    if (t.contains('bluray') || t.contains('bdrip')) qualityIndicators.add('BluRay');
    else if (t.contains('web-dl') || t.contains('webrip') || t.contains(' amzn ') || t.contains(' nf ')) qualityIndicators.add('WEB-DL');
    else if (t.contains('hdtv')) qualityIndicators.add('HDTV');
    
    if (t.contains('remux')) qualityIndicators.add('REMUX');
    if (t.contains('10bit')) qualityIndicators.add('10bit');
    if (t.contains('hdr') || t.contains(' dv ') || t.contains('dovi')) qualityIndicators.add('HDR');

    // 3. Codecs
    String? codec;
    if (t.contains('hevc') || t.contains('x265') || t.contains('h265')) codec = 'HEVC';
    else if (t.contains('x264') || t.contains('h264') || t.contains('avc')) codec = 'x264';

    // 4. Audio
    final List<String> audioFeatures = [];
    if (t.contains('atmos')) audioFeatures.add('Atmos');
    else if (t.contains('dts')) audioFeatures.add('DTS');
    else if (t.contains('aac')) audioFeatures.add('AAC');
    else if (t.contains('ac3') || t.contains('dd5.1') || t.contains('ddp')) audioFeatures.add('DD');

    // 5. Languages
    final List<String> languages = [];
    final isItalian = t.contains('ita') || t.contains('italian') || t.contains('italy') || t.contains(RegExp(r'\bit\b')) || t.contains('🇮🇹');
    final isEnglish = t.contains('eng') || t.contains('english') || t.contains(RegExp(r'\ben\b')) || t.contains('🇬🇧') || t.contains('🇺🇸');
    
    if (isItalian) languages.add('ITA');
    if (isEnglish) languages.add('ENG');
    if (t.contains('multi') && languages.isEmpty) languages.add('MULTI');

    return {
      'resolution': resolution,
      'quality': qualityIndicators,
      'codec': codec,
      'audio': audioFeatures,
      'languages': languages,
    };
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
