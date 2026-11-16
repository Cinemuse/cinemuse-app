import 'dart:convert';

import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_address.dart';
import 'package:dio/dio.dart';

/// Turns a playlist link into the address to open: some links are lookup
/// addresses that answer with the real stream (Rai, Sky, Xtream redirects).
/// A lookup that fails returns the link itself, so the player still tries it.
class LiveLinkResolver {
  static const _logTag = 'LiveLinkResolver';

  static const _browserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  static final Dio _defaultDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
    ),
  );

  final Dio _dio;

  LiveLinkResolver({Dio? dio}) : _dio = dio ?? _defaultDio;

  /// [ask] is the playlist's `cinemuse-ask` label: the broadcaster to ask.
  Future<String> resolve(String url, String? ask) {
    final address = StreamAddress(url);
    if (ask == 'sky') return _askSky(url);
    if (ask == 'rai' || address.isRaiRelinker) return _askRai(url);
    if (address.isXtreamRedirect) return _followRedirect(url);
    return Future.value(url);
  }

  /// Rai answers JSON with the stream address in `video[0]`.
  Future<String> _askRai(String url) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent': _browserAgent,
            'Referer': 'https://www.raiplay.it/',
            'Origin': 'https://www.raiplay.it',
          },
        ),
      );
      final data = _jsonMap(response);
      final videoList = data?['video'];
      if (videoList is List && videoList.isNotEmpty) {
        final stream = videoList[0].toString();
        if (!stream.contains('video_no_available')) return stream;
      }
    } catch (e, st) {
      // The original address is tried as it is.
      AppLogger.warn(_logTag, 'Rai not asked', error: e, stackTrace: st);
    }
    return url;
  }

  /// Sky answers JSON with the stream address in `streaming_url`.
  Future<String> _askSky(String url) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(headers: {'User-Agent': _browserAgent}),
      );
      final streamingUrl = _jsonMap(response)?['streaming_url'];
      if (streamingUrl != null && streamingUrl.toString().isNotEmpty) {
        return streamingUrl.toString();
      }
    } catch (e, st) {
      // The original address is tried as it is.
      AppLogger.warn(_logTag, 'Sky not asked', error: e, stackTrace: st);
    }
    return url;
  }

  Future<String> _followRedirect(String url) async {
    // Only the answer's headers are wanted: a server that answers with the
    // stream itself would otherwise be downloaded until the channel changes.
    final stopBody = CancelToken();
    try {
      final response = await _dio.get(
        url,
        cancelToken: stopBody,
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
          headers: {'User-Agent': 'VLC/3.0.18 LibVLC/3.0.18'},
          responseType: ResponseType.stream,
        ),
      );
      final location = response.headers.value('location');
      if (location != null && location.isNotEmpty) return location;
    } catch (e, st) {
      // The original address is tried as it is.
      AppLogger.warn(_logTag, 'Redirect not checked', error: e, stackTrace: st);
    } finally {
      stopBody.cancel();
    }
    return url;
  }

  static Map? _jsonMap(Response response) {
    if (response.statusCode != 200 || response.data == null) return null;
    final data = response.data;
    return data is Map ? data : jsonDecode(data.toString()) as Map;
  }
}
