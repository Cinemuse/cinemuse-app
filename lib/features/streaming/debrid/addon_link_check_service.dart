import 'dart:async';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:dio/dio.dart';

/// Asks an add-on's link where it leads before it plays.
///
/// An add-on with a debrid key (Torrentio, MediaFusion) answers a file the
/// service won't give (still downloading, refused for copyright, account
/// full) with a redirect to its own 30-second error video, which would play
/// as the film. The real file is GBs; the error videos are 100-150 KB.
class AddonLinkCheckService {
  final Dio _dio;

  AddonLinkCheckService(this._dio);

  static const _logTag = 'AddonLinkCheck';
  static const _maxRedirects = 5;
  static const _timeout = Duration(seconds: 10);

  /// No film or episode is this small; the error videos are 30 times less.
  static const _errorVideoMaxBytes = 5 * 1024 * 1024;

  /// The error videos' names, without `.mp4` and the `_v3`-like version:
  /// Torrentio's (`static_videos.rs`) and MediaFusion's
  /// (`resources/exceptions`). Any other small video is [DebridRefusal.other].
  static const _reasons = {
    'downloading': DebridRefusal.downloading,
    'torrent_downloading': DebridRefusal.downloading,
    'failed_infringement': DebridRefusal.copyright,
    'content_infringing': DebridRefusal.copyright,
    'limits_exceeded': DebridRefusal.limit,
    'torrent_limit': DebridRefusal.limit,
    'queue_full': DebridRefusal.limit,
    'daily_download_limit': DebridRefusal.limit,
    'exceed_remote_traffic_limit': DebridRefusal.limit,
    'not_enough_space': DebridRefusal.limit,
  };

  static final _version = RegExp(r'_v\d+$');

  /// Why [url] leads to an add-on's error video, or null when it leads to
  /// something else, or when that can't be told (no answer in time, no
  /// size): the player then opens it as before and handles what it finds.
  Future<DebridRefusal?> errorVideoReason(
    String url, {
    Map<String, String>? headers,
  }) async {
    final cancel = CancelToken();
    try {
      return await _follow(Uri.parse(url), headers, cancel).timeout(_timeout);
    } on TimeoutException {
      cancel.cancel();
      AppLogger.warn(_logTag, 'No answer in ${_timeout.inSeconds} s');
      return null;
    } on DioException catch (e) {
      // Never log the address: add-on links carry API keys (SEC-06).
      AppLogger.warn(_logTag, 'Not checked (${e.type.name})');
      return null;
    }
  }

  Future<DebridRefusal?> _follow(
    Uri address,
    Map<String, String>? headers,
    CancelToken cancel,
  ) async {
    for (var hop = 0; hop <= _maxRedirects; hop++) {
      final response = await _dio.getUri<ResponseBody>(
        address,
        cancelToken: cancel,
        options: Options(
          followRedirects: false,
          validateStatus: (_) => true,
          responseType: ResponseType.stream,
          // One byte: the answer's headers give the whole size.
          headers: {...?headers, 'Range': 'bytes=0-0'},
        ),
      );
      await response.data?.stream.listen(null).cancel();

      final status = response.statusCode ?? 0;
      if (status >= 300 && status < 400) {
        final location = response.headers.value('location');
        if (location == null) return null;
        address = address.resolve(location);
        continue;
      }
      if (!_isSmallVideo(status, response.headers)) return null;
      return _reasonOf(address);
    }
    return null;
  }

  bool _isSmallVideo(int status, Headers headers) {
    final type = headers.value(Headers.contentTypeHeader) ?? '';
    if (!type.toLowerCase().startsWith('video/')) return false;
    final size = switch (status) {
      // "bytes 0-0/118743": the part after the slash is the whole file.
      206 => int.tryParse(
        headers.value('content-range')?.split('/').last ?? '',
      ),
      // The range was ignored: the length is the whole file.
      200 => int.tryParse(headers.value(Headers.contentLengthHeader) ?? ''),
      _ => null,
    };
    return size != null && size < _errorVideoMaxBytes;
  }

  DebridRefusal _reasonOf(Uri address) {
    final file = address.pathSegments.lastOrNull ?? '';
    final name = file
        .replaceFirst(RegExp(r'\.mp4$', caseSensitive: false), '')
        .replaceFirst(_version, '');
    return _reasons[name] ?? DebridRefusal.other;
  }
}
