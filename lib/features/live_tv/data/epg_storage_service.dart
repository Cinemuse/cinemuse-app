import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path_provider/path_provider.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/features/live_tv/data/epg_parser.dart';

/// Manages on-disk caching of EPG data to enable offline access and fast app startups.
///
/// The cache file can be tens of MB, so reading and writing it run on a
/// background isolate to keep the UI responsive (PERF-01).
class EpgStorageService {
  static const String cacheFileName = 'cinemuse_epg_cache.json';
  static const Duration defaultTtl = Duration(hours: 4);
  static const _tag = 'EpgStorage';

  /// Folder that holds the cache file. Tests pass a temporary folder.
  final Future<Directory> Function() _cacheDirectory;

  EpgStorageService({Future<Directory> Function()? cacheDirectory})
    : _cacheDirectory = cacheDirectory ?? getTemporaryDirectory;

  Future<File> _getCacheFile() async {
    final dir = await _cacheDirectory();
    return File('${dir.path}/$cacheFileName');
  }

  /// Loads cached EPG data if it exists, has not expired and was saved for
  /// [expectedUrl]. Returns `null` when there is no usable cache.
  Future<Map<String, List<EpgProgram>>?> loadCachedEpg({
    String? expectedUrl,
    Duration ttl = defaultTtl,
  }) async {
    try {
      final path = (await _getCacheFile()).path;
      return await Isolate.run(() => _readCache(path, expectedUrl, ttl));
    } catch (e, s) {
      // A broken cache only means the guide is downloaded again.
      AppLogger.warn(
        _tag,
        'Could not read the EPG cache',
        error: e,
        stackTrace: s,
      );
      return null;
    }
  }

  /// Persists parsed EPG data to local disk cache.
  Future<void> saveCachedEpg(
    String url,
    Map<String, List<EpgProgram>> epgData,
  ) async {
    try {
      final path = (await _getCacheFile()).path;
      await Isolate.run(() => _writeCache(path, url, epgData));
    } catch (e, s) {
      // Without a cache the guide is downloaded again next time; nothing breaks.
      AppLogger.warn(
        _tag,
        'Could not save the EPG cache',
        error: e,
        stackTrace: s,
      );
    }
  }
}

/// Runs on a background isolate.
Map<String, List<EpgProgram>>? _readCache(
  String path,
  String? expectedUrl,
  Duration ttl,
) {
  final file = File(path);
  if (!file.existsSync()) return null;

  final content = file.readAsStringSync();
  if (content.isEmpty) return null;

  final jsonMap = json.decode(content);
  if (jsonMap is! Map<String, dynamic>) return null;

  final savedAtMs = jsonMap['savedAt'] as int?;
  if (savedAtMs == null) return null;

  final savedAt = DateTime.fromMillisecondsSinceEpoch(savedAtMs);
  if (DateTime.now().difference(savedAt) > ttl) return null;

  final cachedUrl = jsonMap['url'] as String?;
  if (expectedUrl != null && cachedUrl != null && cachedUrl != expectedUrl) {
    return null;
  }

  // parseJson rebuilds the alias keys that _writeCache leaves out.
  return EpgParser.parseJson(jsonMap['data']);
}

/// Runs on a background isolate.
void _writeCache(String path, String url, Map<String, List<EpgProgram>> epg) {
  // The parser adds alias keys that point to the same list (REV-119). Save
  // each list once, under its first (original) key.
  final written = HashSet<List<EpgProgram>>.identity();
  final serializedData = <String, dynamic>{};
  for (final entry in epg.entries) {
    if (!written.add(entry.value)) continue;
    serializedData[entry.key] = entry.value.map((p) => p.toJson()).toList();
  }

  final payload = {
    'savedAt': DateTime.now().millisecondsSinceEpoch,
    'url': url,
    'data': serializedData,
  };
  File(path).writeAsStringSync(json.encode(payload), flush: true);
}
