import 'package:cinemuse_app/core/services/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/streaming/debrid/base_debrid_service.dart';
import 'package:cinemuse_app/core/utils/media_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

class RealDebridService implements BaseDebridService {
  final Dio _dio;
  final String _apiKey;
  static const String _rdApiUrl = "https://api.real-debrid.com/rest/1.0";

  RealDebridService(this._dio, this._apiKey);

  @override
  String get name => 'Real-Debrid';

  @override
  bool get isEnabled => _apiKey.isNotEmpty;

  Map<String, String> get _headers => { "Authorization": "Bearer $_apiKey" };

  @override
  Future<Map<String, bool>> checkAvailability(List<String> hashes) async {
    if (hashes.isEmpty || !isEnabled) return {};
    
    final hashPath = hashes.join('/');
    try {
      final res = await _dio.get(
        "$_rdApiUrl/torrents/instantAvailability/$hashPath",
        options: Options(headers: _headers),
      );
      
      final data = res.data as Map<String, dynamic>;
      final result = <String, bool>{};
      
      data.forEach((hash, variants) {
        final isAvailable = variants is Map && 
                           variants['rd'] != null && 
                           variants['rd'] is List &&
                           (variants['rd'] as List).isNotEmpty;
        result[hash.toLowerCase()] = isAvailable;
      });
      return result;
    } catch (e) {
      debugPrint('RealDebridService: Availability check failed: $e');
      return {};
    }
  }

  @override
  Future<ResolvedStream?> resolve(
    StreamCandidate candidate, {
    int? season,
    int? episode,
    int? fileId,
  }) async {
    if (!isEnabled) return null;
    final magnet = candidate.magnet;
    final absoluteEpisode = candidate.absoluteEpisode;

    try {
      // 1. Add Magnet
      final addFormData = FormData.fromMap({ "magnet": magnet });
      final addRes = await _dio.post(
        "$_rdApiUrl/torrents/addMagnet",
        data: addFormData,
        options: Options(headers: _headers),
      );
      
      if (addRes.data == null || addRes.data['id'] == null) {
        throw Exception("Failed to add magnet to Real-Debrid (No ID returned)");
      }

      final torrentId = addRes.data['id'];
      debugPrint('RealDebridService: Added magnet, torrentId: $torrentId');

      // 2. Get Info
      final infoRes = await _dio.get(
        "$_rdApiUrl/torrents/info/$torrentId",
        options: Options(headers: _headers),
      );
      
      if (infoRes.data == null) {
        throw Exception("Failed to fetch torrent info from Real-Debrid (Empty response)");
      }
      
      var info = infoRes.data;

      // 3. File Selection Logic
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
      debugPrint('RealDebridService: Found ${allVideoFiles.length} video files');

      int? selectedId = fileId;
      if (selectedId == null && season != null && episode != null) {
        selectedId = _findBestFileMatch(allVideoFiles, season, episode, absoluteEpisode);
        debugPrint('RealDebridService: _findBestFileMatch result: $selectedId');
      }

      // Default to largest if still null
      if (selectedId == null && allVideoFiles.isNotEmpty) {
        final sorted = List<Map<String, dynamic>>.from(allVideoFiles);
        sorted.sort((a, b) => (b['bytes'] as int) - (a['bytes'] as int));
        selectedId = sorted[0]['id'] as int;
      }

      // 4. Select Files if needed
      final List currentlySelected = (info['files'] as List? ?? []).where((f) => f['selected'] == 1).toList();
      final bool selectionMismatch = selectedId != null && 
          (currentlySelected.length != 1 || currentlySelected[0]['id'] != selectedId);

      if (info['status'] == 'waiting_files_selection' || (selectionMismatch && info['status'] == 'downloaded')) {
        final selFormData = FormData.fromMap({ "files": selectedId.toString() });
        await _dio.post(
          "$_rdApiUrl/torrents/selectFiles/$torrentId",
          data: selFormData,
          options: Options(headers: _headers),
        );

        final updatedInfoRes = await _dio.get(
          "$_rdApiUrl/torrents/info/$torrentId",
          options: Options(headers: _headers),
        );
        info = updatedInfoRes.data;
      }

      // 5. Link Unrestricting with Retry Logic
      // Sometimes links are not immediately available even for cached torrents after selection
      int retryCount = 0;
      while ((info['links'] == null || (info['links'] as List).isEmpty) && retryCount < 5) {
        if (info['status'] == 'downloading' || info['status'] == 'compressing' || info['status'] == 'uploading') {
          // If it's actually downloading, it's not "instantly" available even if marked as such
          // or we selected a file that wasn't in the cache variant we checked.
          break; 
        }
        
        debugPrint('RealDebridService: No links found yet for $torrentId, retrying (${retryCount + 1}/5)...');
        await Future.delayed(const Duration(milliseconds: 1000));
        
        final retryRes = await _dio.get(
          "$_rdApiUrl/torrents/info/$torrentId",
          options: Options(headers: _headers),
        );
        info = retryRes.data;
        retryCount++;
      }

      if (info['status'] != 'downloaded') {
        debugPrint('RealDebridService: Stream is not instantly available (Status: ${info['status']})');
        return null;
      }

      if (info['links'] != null && (info['links'] as List).isNotEmpty) {
        final link = info['links'][0];
        final unrestrictFormData = FormData.fromMap({ "link": link });
        final unrestrictRes = await _dio.post(
          "$_rdApiUrl/unrestrict/link",
          data: unrestrictFormData,
          options: Options(headers: _headers),
        );

        final unrestrictData = unrestrictRes.data;
        final finalUrl = unrestrictData['download'] as String;

        if (finalUrl.toLowerCase().contains('.rar')) {
           throw Exception("Resolved URL is an archive (RAR/ZIP), skipping.");
        }

        return ResolvedStream(
          url: finalUrl,
          mimeType: unrestrictData['mimeType'],
          filename: unrestrictData['filename'],
          files: allVideoFiles,
          activeFileId: selectedId,
          provider: name,
          candidate: candidate,
        );
      }
      debugPrint('RealDebridService: Final check: No links found for torrentId: $torrentId (Status: ${info['status']})');
    } catch (e) {
      debugPrint('RealDebridService: Resolve failed: $e');
    }
    return null;
  }

  int? _findBestFileMatch(List<Map<String, dynamic>> files, int season, int episode, int? absoluteEpisode) {
    // 1. Precise Match
    for (final f in files) {
      if (MediaParser.matches(
        f['path'],
        targetSeason: season,
        targetEpisode: episode,
        targetAbsoluteEpisode: absoluteEpisode,
      )) {
        return f['id'] as int;
      }
    }

    // 2. Index-based fallback (if multiple files exist)
    if (files.length > 1) {
      final sortedByPath = List<Map<String, dynamic>>.from(files);
      sortedByPath.sort((a, b) => (a['path'] as String).compareTo(b['path'] as String));
      
      final targetIndex = absoluteEpisode != null ? absoluteEpisode - 1 : episode - 1;
      if (targetIndex >= 0 && targetIndex < sortedByPath.length) {
        return sortedByPath[targetIndex]['id'] as int;
      }
    }

    return null;
  }
}
