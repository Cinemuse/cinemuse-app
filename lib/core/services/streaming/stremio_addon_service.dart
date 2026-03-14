import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:cinemuse_app/core/utils/url_utils.dart';
import 'package:cinemuse_app/core/services/streaming/models/stremio_addon.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StremioAddonService {
  final Dio _dio;

  StremioAddonService(this._dio);

  /// Fetches and validates a Stremio manifest from the given URL.
  Future<StremioAddon> fetchManifest(String url) async {
    // Use PlayTorrio style splitting to handle query params (e.g. ?apikey=...)
    final parts = UrlUtils.splitStremioUrl(url);
    final baseUrl = parts.baseUrl;
    final queryParams = parts.queryParams;

    if (baseUrl.isEmpty || !UrlUtils.isSecureUrl(baseUrl)) {
      throw Exception('Invalid URL format');
    }

    try {
      final manifestUrl = UrlUtils.unencodeStremioUrl("$baseUrl/manifest.json${queryParams != null ? '?$queryParams' : ''}");
      final response = await _dio.get(
        manifestUrl,
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Addon unreachable (Status: ${response.statusCode})');
      }

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid manifest data format');
      }

      // Basic validation of required fields
      if (data['id'] == null || data['name'] == null) {
        throw Exception('Manifest is missing required fields (id or name)');
      }

      return StremioAddon.fromJson({
        ...data,
        'baseUrl': baseUrl,
        'queryParams': queryParams,
      });
    } on DioException catch (e) {
      throw Exception('Failed to fetch manifest: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching manifest: $e');
    }
  }
}

final stremioAddonServiceProvider = Provider((ref) {
  final dio = ref.watch(dioProvider);
  return StremioAddonService(dio);
});
