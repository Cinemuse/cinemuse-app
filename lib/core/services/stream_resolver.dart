import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:cinemuse_app/core/services/kitsu_mapping_service.dart';
import 'package:cinemuse_app/core/services/tmdb_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String rdApiUrl = "https://api.real-debrid.com/rest/1.0";

final streamResolverProvider = Provider((ref) {
  return StreamResolver(
    ref.read(dioProvider), 
    ref.read(tmdbServiceProvider),
    ref.read(kitsuMappingServiceProvider),
  );
});

class StreamResolver {
  final Dio _dio;
  final TmdbService _tmdbService;
  final KitsuMappingService _kitsuMappingService;

  StreamResolver(this._dio, this._tmdbService, this._kitsuMappingService);

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

      // 1. Resolve IDs and detect Anime
      int? tmdbId;
      if (!queryId.startsWith('tt')) {
        tmdbId = int.tryParse(queryId);
      }

      final details = await _tmdbService.getMediaDetails(queryId, type);
      if (details == null) throw Exception("Could not fetch media details");

      imdbId = details['external_ids']?['imdb_id'] ?? details['imdb_id'];
      if (imdbId == null && tmdbId != null) {
        imdbId = await _tmdbService.getImdbId(tmdbId, type);
      }

      if (imdbId == null) throw Exception("Could not resolve IMDB ID");

      KitsuMapping? kitsuMapping;
      if (TmdbService.isAnime(details) && tmdbId != null) {
        kitsuMapping = await _kitsuMappingService.getMapping(
          tmdbId: tmdbId,
          type: type,
          season: season,
          episode: episode,
        );
      }

      // 2. Search Torrents
      final isAnime = TmdbService.isAnime(details);
      var torrents = await _searchStreams(imdbId, type, season, episode, kitsuMapping: kitsuMapping, isAnime: isAnime);
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
  Future<Map<String, dynamic>?> resolveStream(
    String magnet, 
    String rdKey, {
    int? season, 
    int? episode,
    int? absoluteEpisode,
    int? fileId,
  }) async {
    return _resolveRealDebrid(
      magnet, 
      rdKey, 
      season: season, 
      episode: episode, 
      absoluteEpisode: absoluteEpisode,
      fileId: fileId,
    );
  }

  // Delegated Methods to TmdbService
  Future<List<Map<String, dynamic>>> getTrending() => _tmdbService.getTrending();
  Future<List<Map<String, dynamic>>> getPopularMovies() => _tmdbService.getPopularMovies();
  Future<List<Map<String, dynamic>>> getPopularSeries() => _tmdbService.getPopularSeries();

  Future<List<Map<String, dynamic>>> _searchStreams(
    String imdbId,
    String type,
    int? season,
    int? episode, {
    KitsuMapping? kitsuMapping,
    bool isAnime = false,
  }) async {
    String queryId = imdbId;
    if (type == 'tv' && season != null && episode != null) {
      queryId = "$imdbId:$season:$episode";
    }

    final absoluteEpisode = kitsuMapping?.absoluteEpisode;

    final List<Future<List<Map<String, dynamic>>>> providerFutures = [];

    // 1. Torrentio
    if (kitsuMapping != null) {
      // Use Kitsu if available (better coverage for anime)
      providerFutures.add(_fetchTorrentioKitsu(type, kitsuMapping));
    } else {
      // Standard IMDB fetch
      providerFutures.add(_fetchTorrentio(type, queryId, absoluteEpisode));
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

  Future<List<Map<String, dynamic>>> _fetchTorrentio(String type, String queryId, [int? absoluteEpisode]) async {
    try {
      final torrentioType = type == 'tv' ? 'series' : type;
      final url = "https://torrentio.strem.fun/stream/$torrentioType/$queryId.json";
      print('StreamResolver: Fetching Torrentio: $url');
      final res = await _dio.get(url, options: Options(receiveTimeout: const Duration(seconds: 25)));
      if (res.statusCode == 200 && res.data['streams'] != null) {
        final streamsData = res.data['streams'] as List;
        return streamsData.map((s) {
          return {
            'title': (s['title'] ?? "").replaceAll('\n', " "),
            'infoHash': s['infoHash'],
            'magnet': "magnet:?xt=urn:btih:${s['infoHash']}&dn=${Uri.encodeComponent(s['title'] ?? "")}",
            'seeds': s['seeds'] ?? 0,
            'provider': 'Torrentio',
            'absoluteEpisode': absoluteEpisode,
          };
        }).toList();
      }
    } catch (e) {
      print('Torrentio fetch failed: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _fetchTorrentioKitsu(String type, KitsuMapping mapping) async {
    try {
      // Torrentio supports 'movie', 'series', and 'anime' types.
      // For Kitsu, 'anime' is the official type in the manifest for series.
      final torrentioType = type == 'movie' ? 'movie' : 'anime';
      
      String queryId = "kitsu:${mapping.kitsuId}";
      if (torrentioType == 'anime') {
        final ep = mapping.absoluteEpisode ?? 1;
        queryId = "kitsu:${mapping.kitsuId}:$ep";
      }
      
      final url = "https://torrentio.strem.fun/stream/$torrentioType/$queryId.json";
      print('StreamResolver: Fetching Torrentio (Kitsu): $url');
      final res = await _dio.get(url, options: Options(receiveTimeout: const Duration(seconds: 25)));
      
      if (res.statusCode == 200 && res.data['streams'] != null) {
        final streamsData = res.data['streams'] as List;
        return streamsData.map((s) {
          return {
            'title': " (Kitsu) ${(s['title'] ?? "").replaceAll('\n', " ")}",
            'infoHash': s['infoHash'],
            'magnet': "magnet:?xt=urn:btih:${s['infoHash']}&dn=${Uri.encodeComponent(s['title'] ?? "")}",
            'seeds': s['seeds'] ?? 0,
            'provider': 'Torrentio (Kitsu)',
            'absoluteEpisode': mapping.absoluteEpisode,
          };
        }).toList();
      }
    } catch (e) {
      print('Torrentio Kitsu fetch failed: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> _resolveRealDebrid(
    String magnet, 
    String apiKey, {
    int? season, 
    int? episode,
    int? absoluteEpisode,
    int? fileId,
  }) async {
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

    // Filter and map video files first to use in selection logic
    final List<Map<String, dynamic>> allVideoFiles = (info['files'] as List? ?? [])
        .where((f) {
          final path = (f['path'] as String? ?? '').toLowerCase();
          return path.endsWith('.mp4') || path.endsWith('.mkv') || path.endsWith('.avi') || 
                 path.endsWith('.mov') || path.endsWith('.m4v') || path.endsWith('.webm') ||
                 path.endsWith('.flv') || path.endsWith('.wmv');
        })
        .map((f) => <String, dynamic>{
          'id': f['id'] as int,
          'path': f['path'] as String,
          'bytes': f['bytes'] as int? ?? 0,
          'selected': f['selected'] == 1,
        }).toList();

    print('CINEMUSE-DEBUG: RD Torrent $torrentId files found: ${allVideoFiles.length}');

    int? selectedId = fileId;
    if (selectedId == null && season != null && episode != null) {
      final sStr = season.toString().padLeft(2, '0');
      final eStr = episode.toString().padLeft(2, '0');
      
      final patterns = [
        RegExp('s$sStr\\s*e$eStr', caseSensitive: false),
        RegExp('${season}x$eStr', caseSensitive: false),
        RegExp('e$eStr\\b', caseSensitive: false),
        RegExp('\\b${episode}\\b', caseSensitive: false),
      ];

      // If absolute episode is available (anime), add more specific patterns
      if (absoluteEpisode != null) {
        final absStr = absoluteEpisode.toString().padLeft(2, '0');
        patterns.insert(0, RegExp(' - $absStr\\b', caseSensitive: false)); // Common Erai-raws/SubsPlease format
        patterns.insert(1, RegExp('episode $absStr\\b', caseSensitive: false));
        patterns.insert(2, RegExp('\\b$absStr\\b', caseSensitive: false));
      }

      for (final pattern in patterns) {
        Map<String, dynamic>? foundMatch;
        for (final f in allVideoFiles) {
          if (pattern.hasMatch(f['path'])) {
            foundMatch = f;
            break;
          }
        }
        
        if (foundMatch != null) {
          selectedId = foundMatch['id'] as int;
          print('CINEMUSE-DEBUG: Auto-matched S${season}E${episode} (abs: $absoluteEpisode) -> ${foundMatch['path']}');
          break;
        }
      }

      // Index-based fallback for season packs/anime packs
      if (selectedId == null && allVideoFiles.length > 1) {
        // Sort files by path to ensure predictable order
        final sortedByPath = List<Map<String, dynamic>>.from(allVideoFiles);
        sortedByPath.sort((a, b) => (a['path'] as String).compareTo(b['path'] as String));
        
        final targetIndex = absoluteEpisode != null ? absoluteEpisode - 1 : episode - 1;
        if (targetIndex >= 0 && targetIndex < sortedByPath.length) {
          selectedId = sortedByPath[targetIndex]['id'] as int;
          print('CINEMUSE-DEBUG: Index-based match ($targetIndex) -> ${sortedByPath[targetIndex]['path']}');
        }
      }
    }

    // Default to largest if still null
    if (selectedId == null && allVideoFiles.isNotEmpty) {
      final sorted = List<Map<String, dynamic>>.from(allVideoFiles);
      sorted.sort((a, b) => (b['bytes'] as int) - (a['bytes'] as int));
      selectedId = sorted[0]['id'] as int;
      print('CINEMUSE-DEBUG: Fallback to largest file: ${sorted[0]['path']}');
    }

    // Check if we need to (re)select files
    final List currentlySelected = (info['files'] as List? ?? []).where((f) => f['selected'] == 1).toList();
    final bool selectionMismatch = selectedId != null && 
        (currentlySelected.length != 1 || currentlySelected[0]['id'] != selectedId);

    if (info['status'] == 'waiting_files_selection' || (selectionMismatch && info['status'] == 'downloaded')) {
      print('CINEMUSE-DEBUG: Selecting file $selectedId (status: ${info['status']})');
      final selFormData = FormData.fromMap({ "files": selectedId.toString() });

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
      // Find the link corresponding to our selected file if possible
      // Real-Debrid tends to return links in the order of selected files
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
        'files': allVideoFiles,
        'activeFileId': selectedId,
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

    // 6. File Size
    String? size;
    // Regex matches numbers followed by units (GB, MB, GiB, etc.) 
    // but uses a negative lookahead to ensure we don't match something like "10bit"
    final sizeMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(GB|MB|GiB|MiB|KB|B)(?!bit)', caseSensitive: false).firstMatch(title);
    if (sizeMatch != null) {
      size = "${sizeMatch.group(1)} ${sizeMatch.group(2)}".toUpperCase();
    }

    return {
      'resolution': resolution,
      'quality': qualityIndicators,
      'codec': codec,
      'audio': audioFeatures,
      'languages': languages,
      'size': size,
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
