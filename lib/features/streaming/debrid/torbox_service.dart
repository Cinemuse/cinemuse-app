import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/streaming/debrid/base_debrid_service.dart';
import 'package:cinemuse_app/features/streaming/debrid/debrid_file_picker.dart';
import 'package:cinemuse_app/features/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/features/streaming/models/stream_candidate.dart';
import 'package:dio/dio.dart';

/// TorBox debrid service implementation.
class TorBoxService implements BaseDebridService {
  static const String _logTag = 'TorBoxService';

  final Dio _dio;
  final String _apiKey;
  static const String _tbApiUrl = "https://api.torbox.app/v1/api";

  TorBoxService(this._dio, this._apiKey);

  @override
  String get name => 'TorBox';

  @override
  bool get isEnabled => _apiKey.trim().isNotEmpty;

  Map<String, String> get _headers => {
    "Authorization": "Bearer ${_apiKey.trim()}",
  };

  @override
  Future<Map<String, bool>> checkAvailability(List<String> hashes) async {
    if (hashes.isEmpty || !isEnabled) return {};

    final result = <String, bool>{};
    const chunkSize = 50;

    for (var i = 0; i < hashes.length; i += chunkSize) {
      final chunk = hashes.sublist(
        i,
        i + chunkSize > hashes.length ? hashes.length : i + chunkSize,
      );
      try {
        final res = await _dio.get(
          "$_tbApiUrl/torrents/checkcached",
          queryParameters: {"hash": chunk.join(','), "format": "object"},
          options: Options(headers: _headers),
        );

        if (res.data is Map && res.data['data'] is Map) {
          final data = res.data['data'] as Map<String, dynamic>;
          data.forEach((hash, val) {
            final isAvailable = val == true || (val is Map && val.isNotEmpty);
            result[hash.toLowerCase()] = isAvailable;
          });
        }
      } catch (e) {
        AppLogger.warn(_logTag, 'checkAvailability chunk error', error: e);
      }
    }

    return result;
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
    if (magnet.isEmpty) return null;

    try {
      final torrentId = await _addTorrent(magnet, candidate.infoHash);
      if (torrentId == null) {
        throw Exception("Failed to get torrent ID from TorBox");
      }

      final torrentInfo = await _getTorrentInfo(torrentId);
      if (torrentInfo == null) {
        throw Exception("Failed to get torrent info from TorBox");
      }

      final files = _extractVideoFiles(torrentInfo['files']);
      if (files.isEmpty) {
        throw Exception("No video files found in TorBox torrent");
      }

      // No file-index hint: TorBox's file ids don't follow the add-on's
      // index (Torrentio itself matches TorBox files by name).
      final selectedId = DebridFilePicker.pick(
        files,
        fileId: fileId,
        hintFileName: candidate.fileName,
        season: season,
        episode: episode,
        absoluteEpisode: candidate.absoluteEpisode,
      );
      // The episode's file is not known: try the next source (REV-318).
      if (selectedId == null) return null;

      final streamUrl = await _requestDownloadLink(torrentId, selectedId);
      if (streamUrl == null) {
        throw Exception("Failed to generate download link from TorBox");
      }

      if (streamUrl.toLowerCase().contains('.rar')) {
        throw Exception("Resolved URL is an archive (RAR/ZIP), skipping.");
      }

      return ResolvedStream(
        url: streamUrl,
        filename: torrentInfo['name'] as String?,
        files: files,
        activeFileId: selectedId,
        provider: name,
        candidate: candidate,
      );
    } catch (e) {
      AppLogger.warn(_logTag, 'Resolution failed', error: e);
      return null;
    }
  }

  Future<int?> _addTorrent(String magnet, String infoHash) async {
    try {
      final formData = FormData.fromMap({
        "magnet": magnet,
        "seed": "1",
        "allow_zip": "false",
      });

      final res = await _dio.post(
        "$_tbApiUrl/torrents/createtorrent",
        data: formData,
        options: Options(headers: _headers),
      );

      if (res.data is Map && res.data['data'] is Map) {
        final data = res.data['data'] as Map<String, dynamic>;
        if (data['torrent_id'] != null) {
          return data['torrent_id'] is int
              ? data['torrent_id'] as int
              : int.tryParse(data['torrent_id'].toString());
        }
      }
    } catch (e) {
      AppLogger.warn(_logTag, 'createtorrent error, checking mylist', error: e);
    }

    // Fallback: check mylist if torrent was already added
    return _findExistingTorrentId(infoHash);
  }

  Future<int?> _findExistingTorrentId(String infoHash) async {
    if (infoHash.isEmpty) return null;
    try {
      final res = await _dio.get(
        "$_tbApiUrl/torrents/mylist",
        options: Options(headers: _headers),
      );

      if (res.data is Map && res.data['data'] is List) {
        final list = res.data['data'] as List;
        for (final item in list) {
          if (item is Map &&
              (item['hash'] as String? ?? '').toLowerCase() ==
                  infoHash.toLowerCase()) {
            return item['id'] as int?;
          }
        }
      }
    } catch (e) {
      AppLogger.warn(_logTag, '_findExistingTorrentId error', error: e);
    }
    return null;
  }

  Future<Map<String, dynamic>?> _getTorrentInfo(int torrentId) async {
    try {
      final res = await _dio.get(
        "$_tbApiUrl/torrents/mylist",
        queryParameters: {"id": torrentId},
        options: Options(headers: _headers),
      );

      if (res.data is Map && res.data['data'] != null) {
        final data = res.data['data'];
        if (data is Map<String, dynamic>) {
          return data;
        } else if (data is List && data.isNotEmpty) {
          return data.first as Map<String, dynamic>;
        }
      }
    } catch (e) {
      AppLogger.warn(_logTag, '_getTorrentInfo error', error: e);
    }
    return null;
  }

  List<Map<String, dynamic>> _extractVideoFiles(dynamic rawFiles) {
    if (rawFiles is! List) return const [];

    return rawFiles
        .where((f) {
          final path = f['name'] as String? ?? f['short_name'] as String? ?? '';
          return DebridFilePicker.isVideo(path);
        })
        .map(
          (f) => <String, dynamic>{
            'id': f['id'] as int? ?? 0,
            'path': f['name'] as String? ?? f['short_name'] as String? ?? '',
            'bytes': f['size'] as int? ?? 0,
            'selected': true,
          },
        )
        .toList();
  }

  Future<String?> _requestDownloadLink(int torrentId, int fileId) async {
    try {
      final queryParams = <String, dynamic>{
        "token": _apiKey.trim(),
        "torrent_id": torrentId,
        "file_id": fileId,
      };

      final res = await _dio.get(
        "$_tbApiUrl/torrents/requestdl",
        queryParameters: queryParams,
        options: Options(headers: _headers),
      );

      if (res.data is Map && res.data['data'] is String) {
        return res.data['data'] as String;
      }
    } catch (e) {
      AppLogger.warn(_logTag, '_requestDownloadLink error', error: e);
    }
    return null;
  }
}
