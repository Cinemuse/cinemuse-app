import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:cinemuse_app/core/utils/url_utils.dart';
import 'package:cinemuse_app/features/streaming/models/stremio_addon.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fetches Stremio add-on manifests.
class StremioAddonService {
  final Dio _dio;

  StremioAddonService(this._dio);

  /// Fetches and validates a Stremio manifest from the given URL.
  ///
  /// Throws a [ValidationFailure] when [url] is not an add-on link or the
  /// manifest is broken, and a [NetworkFailure] / [ServerFailure] when the
  /// add-on can't be reached.
  Future<StremioAddon> fetchManifest(String url) async {
    // Use PlayTorrio style splitting to handle query params (e.g. ?apikey=...)
    final parts = UrlUtils.splitStremioUrl(url);
    final baseUrl = parts.baseUrl;
    final queryParams = parts.queryParams;

    if (baseUrl.isEmpty || !UrlUtils.isHttpUrl(baseUrl)) {
      throw const ValidationFailure('Add-on URL is not an http(s) URL');
    }

    final manifestUrl = UrlUtils.unencodeStremioUrl(
      "$baseUrl/manifest.json${queryParams != null ? '?$queryParams' : ''}",
    );
    final Response<dynamic> response;
    try {
      response = await _dio.get(
        manifestUrl,
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
    } on DioException catch (e, st) {
      final status = e.response?.statusCode;
      final message = 'Add-on manifest request failed (${e.type.name})';
      throw e.type == DioExceptionType.badResponse
          ? ServerFailure(message, statusCode: status, cause: e, stackTrace: st)
          : NetworkFailure(message, cause: e, stackTrace: st);
    }

    if (response.statusCode != 200) {
      throw ServerFailure(
        'Add-on manifest answered ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const ValidationFailure('Add-on manifest is not a JSON object');
    }
    if (data['id'] == null || data['name'] == null) {
      throw const ValidationFailure('Add-on manifest has no id or name');
    }

    try {
      return StremioAddon.fromJson({
        ...data,
        'baseUrl': baseUrl,
        'queryParams': queryParams,
      });
    } catch (e, st) {
      throw ValidationFailure(
        'Add-on manifest has an unexpected shape',
        cause: e,
        stackTrace: st,
      );
    }
  }
}

final stremioAddonServiceProvider = Provider((ref) {
  final dio = ref.watch(dioProvider);
  return StremioAddonService(dio);
});
