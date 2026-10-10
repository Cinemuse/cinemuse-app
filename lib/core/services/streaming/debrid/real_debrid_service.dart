import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/services/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/streaming/debrid/base_debrid_service.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/core/utils/media_parser.dart';
import 'package:dio/dio.dart';

/// Resolves torrents to playable links through the Real-Debrid API.
///
/// Throws an [AppFailure] when RD or the network fails; returns `null` when
/// the torrent is simply not cached on RD.
class RealDebridService implements BaseDebridService {
  final Dio _dio;
  final String _apiKey;
  static const String _rdApiUrl = "https://api.real-debrid.com/rest/1.0";
  static const String _tag = 'RealDebrid';

  RealDebridService(this._dio, this._apiKey);

  @override
  String get name => 'Real-Debrid';

  @override
  bool get isEnabled => _apiKey.isNotEmpty;

  Map<String, String> get _headers => {"Authorization": "Bearer $_apiKey"};

  /// Always "unknown" (empty map): RD disabled `/torrents/instantAvailability`
  /// in late 2024 and has no replacement. Adding every torrent just to check it
  /// would cost several requests each and hit RD's rate limit (STR-03).
  @override
  Future<Map<String, bool>> checkAvailability(List<String> hashes) async => {};

  /// Adds the magnet to the account and returns a playable link.
  ///
  /// When no link comes out (not cached, no video file, error), the torrent
  /// is deleted again so it doesn't stay on the account downloading (STR-03).
  /// A torrent that resolved is kept: it's already downloaded (uses no active
  /// slot) and deleting it could break the link while it plays.
  @override
  Future<ResolvedStream?> resolve(
    StreamCandidate candidate, {
    int? season,
    int? episode,
    int? fileId,
  }) async {
    if (!isEnabled) return null;

    final torrentId = await _guard(() => _addMagnet(candidate.magnet));
    ResolvedStream? stream;
    try {
      stream = await _guard(
        () => _resolveTorrent(
          torrentId,
          candidate,
          season: season,
          episode: episode,
          fileId: fileId,
        ),
      );
      return stream;
    } finally {
      if (stream == null) await _deleteTorrent(torrentId);
    }
  }

  Future<String> _addMagnet(String magnet) async {
    final res = await _dio.post(
      "$_rdApiUrl/torrents/addMagnet",
      data: FormData.fromMap({"magnet": magnet}),
      options: Options(headers: _headers),
    );
    final id = res.data is Map ? res.data['id'] : null;
    if (id == null) {
      throw const StreamingFailure('Real-Debrid returned no torrent id');
    }
    return id.toString();
  }

  Future<ResolvedStream?> _resolveTorrent(
    String torrentId,
    StreamCandidate candidate, {
    int? season,
    int? episode,
    int? fileId,
  }) async {
    var info = await _fetchInfo(torrentId);
    final videoFiles = _videoFiles(info);
    // Nothing playable: don't send `files=null` to selectFiles.
    if (videoFiles.isEmpty) return null;

    final selectedId =
        fileId ??
        (season != null && episode != null
            ? _findBestFileMatch(
                videoFiles,
                season,
                episode,
                candidate.absoluteEpisode,
              )
            : null) ??
        _largestFileId(videoFiles);

    if (_needsSelection(info, selectedId)) {
      await _dio.post(
        "$_rdApiUrl/torrents/selectFiles/$torrentId",
        data: FormData.fromMap({"files": selectedId.toString()}),
        options: Options(headers: _headers),
      );
      info = await _fetchInfo(torrentId);
    }

    info = await _waitForLinks(torrentId, info);
    final links = info['links'] as List? ?? const [];
    if (info['status'] != 'downloaded' || links.isEmpty) {
      AppLogger.debug(_tag, 'Not cached (status ${info['status']})');
      return null;
    }

    return _unrestrict(
      links.first as String,
      candidate,
      videoFiles,
      selectedId,
    );
  }

  Future<Map<String, dynamic>> _fetchInfo(String torrentId) async {
    final res = await _dio.get(
      "$_rdApiUrl/torrents/info/$torrentId",
      options: Options(headers: _headers),
    );
    if (res.data is! Map<String, dynamic>) {
      throw const StreamingFailure('Real-Debrid sent no torrent info');
    }
    return res.data as Map<String, dynamic>;
  }

  static const _videoExtensions = [
    '.mp4',
    '.mkv',
    '.avi',
    '.mov',
    '.m4v',
    '.webm',
    '.flv',
    '.wmv',
  ];

  List<Map<String, dynamic>> _videoFiles(Map<String, dynamic> info) =>
      (info['files'] as List? ?? [])
          .where((f) {
            final path = (f['path'] as String? ?? '').toLowerCase();
            return _videoExtensions.any(path.endsWith);
          })
          .map(
            (f) => <String, dynamic>{
              'id': f['id'] as int,
              'path': f['path'] as String,
              'bytes': f['bytes'] as int? ?? 0,
              'selected': f['selected'] == 1,
            },
          )
          .toList();

  int _largestFileId(List<Map<String, dynamic>> files) {
    final sorted = List<Map<String, dynamic>>.from(files)
      ..sort((a, b) => (b['bytes'] as int) - (a['bytes'] as int));
    return sorted.first['id'] as int;
  }

  bool _needsSelection(Map<String, dynamic> info, int selectedId) {
    final selected = (info['files'] as List? ?? [])
        .where((f) => f['selected'] == 1)
        .toList();
    final isMismatch =
        selected.length != 1 || selected.first['id'] != selectedId;
    return info['status'] == 'waiting_files_selection' ||
        (isMismatch && info['status'] == 'downloaded');
  }

  /// Links can lag a moment behind selection even for cached torrents, so
  /// poll a few times. Stops at once when RD is really downloading.
  Future<Map<String, dynamic>> _waitForLinks(
    String torrentId,
    Map<String, dynamic> info,
  ) async {
    const busy = ['downloading', 'compressing', 'uploading'];
    var current = info;
    for (var retry = 0; retry < 5; retry++) {
      final links = current['links'] as List? ?? const [];
      if (links.isNotEmpty || busy.contains(current['status'])) break;
      await Future<void>.delayed(const Duration(seconds: 1));
      current = await _fetchInfo(torrentId);
    }
    return current;
  }

  Future<ResolvedStream> _unrestrict(
    String link,
    StreamCandidate candidate,
    List<Map<String, dynamic>> videoFiles,
    int selectedId,
  ) async {
    final res = await _dio.post(
      "$_rdApiUrl/unrestrict/link",
      data: FormData.fromMap({"link": link}),
      options: Options(headers: _headers),
    );
    final data = res.data as Map<String, dynamic>;
    final url = data['download'] as String;
    if (url.toLowerCase().contains('.rar')) {
      throw const StreamingFailure('Real-Debrid link is an archive (RAR)');
    }
    return ResolvedStream(
      url: url,
      mimeType: data['mimeType'],
      filename: data['filename'],
      files: videoFiles,
      activeFileId: selectedId,
      provider: name,
      candidate: candidate,
    );
  }

  Future<void> _deleteTorrent(String torrentId) async {
    try {
      await _dio.delete(
        "$_rdApiUrl/torrents/delete/$torrentId",
        options: Options(headers: _headers),
      );
    } catch (e, st) {
      // Safe to continue: a leftover torrent only wastes a slot, and the
      // resolve result (or its own failure) matters more to the caller.
      AppLogger.warn(
        _tag,
        'Could not delete torrent $torrentId',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Turns Dio and parsing errors into an [AppFailure].
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on AppFailure {
      rethrow;
    } on DioException catch (e, st) {
      throw _failureFromDio(e, st);
    } catch (e, st) {
      // A missing or wrongly typed field in RD's answer.
      throw StreamingFailure(
        'Unexpected Real-Debrid answer',
        cause: e,
        stackTrace: st,
      );
    }
  }

  AppFailure _failureFromDio(DioException e, StackTrace st) {
    final status = e.response?.statusCode;
    return switch (e.type) {
      DioExceptionType.badResponse when status == 401 || status == 403 =>
        AuthFailure(
          'Real-Debrid refused the API key ($status)',
          cause: e,
          stackTrace: st,
        ),
      DioExceptionType.badResponse => ServerFailure(
        'Real-Debrid error',
        statusCode: status,
        cause: e,
        stackTrace: st,
      ),
      DioExceptionType.cancel => UnknownFailure(
        'Real-Debrid request cancelled',
        cause: e,
        stackTrace: st,
      ),
      _ => NetworkFailure(
        'Could not reach Real-Debrid',
        cause: e,
        stackTrace: st,
      ),
    };
  }

  int? _findBestFileMatch(
    List<Map<String, dynamic>> files,
    int season,
    int episode,
    int? absoluteEpisode,
  ) {
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
      sortedByPath.sort(
        (a, b) => (a['path'] as String).compareTo(b['path'] as String),
      );

      final targetIndex = absoluteEpisode != null
          ? absoluteEpisode - 1
          : episode - 1;
      if (targetIndex >= 0 && targetIndex < sortedByPath.length) {
        return sortedByPath[targetIndex]['id'] as int;
      }
    }

    return null;
  }
}
