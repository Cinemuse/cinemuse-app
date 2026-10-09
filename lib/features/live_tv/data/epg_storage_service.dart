import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/features/live_tv/data/epg_parser.dart';

/// Manages on-disk caching of EPG data to enable offline access and fast app startups.
class EpgStorageService {
  static const String _cacheFileName = 'cinemuse_epg_cache.json';
  static const Duration defaultTtl = Duration(hours: 4);

  Future<File> _getCacheFile() async {
    final tempDir = await getTemporaryDirectory();
    return File('${tempDir.path}/$_cacheFileName');
  }

  /// Loads cached EPG data if it exists and has not expired.
  Future<Map<String, List<EpgProgram>>?> loadCachedEpg({
    String? expectedUrl,
    Duration ttl = defaultTtl,
  }) async {
    try {
      final file = await _getCacheFile();
      if (!file.existsSync()) return null;

      final content = await file.readAsString();
      if (content.isEmpty) return null;

      final jsonMap = json.decode(content);
      if (jsonMap is! Map<String, dynamic>) return null;

      final savedAtMs = jsonMap['savedAt'] as int?;
      if (savedAtMs == null) return null;

      final savedAt = DateTime.fromMillisecondsSinceEpoch(savedAtMs);
      if (DateTime.now().difference(savedAt) > ttl) {
        // Cache expired
        return null;
      }

      if (expectedUrl != null) {
        final cachedUrl = jsonMap['url'] as String?;
        if (cachedUrl != null && cachedUrl != expectedUrl) {
          // Different URL configured
          return null;
        }
      }

      final rawData = jsonMap['data'];
      return EpgParser.parseJson(rawData);
    } catch (e) {
      debugPrint('EpgStorageService: Error reading cache: $e');
      return null;
    }
  }

  /// Persists parsed EPG data to local disk cache.
  Future<void> saveCachedEpg(
    String url,
    Map<String, List<EpgProgram>> epgData,
  ) async {
    try {
      final file = await _getCacheFile();
      final serializedData = <String, dynamic>{};

      for (final entry in epgData.entries) {
        serializedData[entry.key] = entry.value.map((p) => p.toJson()).toList();
      }

      final payload = {
        'savedAt': DateTime.now().millisecondsSinceEpoch,
        'url': url,
        'data': serializedData,
      };

      await file.writeAsString(json.encode(payload), flush: true);
    } catch (e) {
      debugPrint('EpgStorageService: Error saving cache: $e');
    }
  }

  /// Clears the local disk cache.
  Future<void> clearCache() async {
    try {
      final file = await _getCacheFile();
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (e, s) {
      developer.log(
        'Failed to clear EPG disk cache',
        name: 'EpgStorageService',
        error: e,
        stackTrace: s,
      );
    }
  }
}
