import 'package:cinemuse_app/core/services/streaming/debrid/base_debrid_service.dart';
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
        final isAvailable = variants is Map && variants['rd'] != null && (variants['rd'] as List).isNotEmpty;
        result[hash.toLowerCase()] = isAvailable;
      });
      return result;
    } catch (e) {
      print('RealDebridService: Availability check failed: $e');
      return {};
    }
  }

  @override
  Future<Map<String, dynamic>?> resolve(
    String magnet, {
    int? season,
    int? episode,
    int? absoluteEpisode,
    int? fileId,
  }) async {
    if (!isEnabled) return null;

    try {
      // 1. Add Magnet
      final addFormData = FormData.fromMap({ "magnet": magnet });
      final addRes = await _dio.post(
        "$_rdApiUrl/torrents/addMagnet",
        data: addFormData,
        options: Options(headers: _headers),
      );
      final torrentId = addRes.data['id'];

      // 2. Get Info
      final infoRes = await _dio.get(
        "$_rdApiUrl/torrents/info/$torrentId",
        options: Options(headers: _headers),
      );
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

      int? selectedId = fileId;
      if (selectedId == null && season != null && episode != null) {
        selectedId = _findBestFileMatch(allVideoFiles, season, episode, absoluteEpisode);
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

         final infoRes2 = await _dio.get(
          "$_rdApiUrl/torrents/info/$torrentId",
          options: Options(headers: _headers),
        );
        info = infoRes2.data;
      }

      // 5. Unrestrict Link
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

        return {
          'url': finalUrl,
          'mimeType': unrestrictData['mimeType'],
          'filename': unrestrictData['filename'],
          'originalUrl': finalUrl,
          'files': allVideoFiles,
          'activeFileId': selectedId,
          'provider': name,
        };
      }
    } catch (e) {
      print('RealDebridService: Resolve failed: $e');
    }
    return null;
  }

  int? _findBestFileMatch(List<Map<String, dynamic>> files, int season, int episode, int? absoluteEpisode) {
    final sStr = season.toString().padLeft(2, '0');
    final eStr = episode.toString().padLeft(2, '0');
    
    final patterns = [
      RegExp('s$sStr\\s*e$eStr', caseSensitive: false),
      RegExp('${season}x$eStr', caseSensitive: false),
      RegExp('e$eStr\\b', caseSensitive: false),
      RegExp('\\b${episode}\\b', caseSensitive: false),
    ];

    if (absoluteEpisode != null) {
      final absStr = absoluteEpisode.toString().padLeft(2, '0');
      patterns.insert(0, RegExp(' - $absStr\\b', caseSensitive: false));
      patterns.insert(1, RegExp('episode $absStr\\b', caseSensitive: false));
      patterns.insert(2, RegExp('\\b$absStr\\b', caseSensitive: false));
    }

    for (final pattern in patterns) {
      for (final f in files) {
        if (pattern.hasMatch(f['path'])) return f['id'] as int;
      }
    }

    // Index-based fallback
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
