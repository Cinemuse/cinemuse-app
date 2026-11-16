import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path_provider/path_provider.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/features/live_tv/data/epg_parser.dart';

/// Manages on-disk caching of EPG data to enable offline access and fast app startups.
/// Each guide has its own cache file, named after the guide's id.
///
/// The cache file can be tens of MB, so reading and writing it run on a
/// background isolate to keep the UI responsive (PERF-01).
class EpgStorageService {
  static const Duration defaultTtl = Duration(hours: 4);
  static const _tag = 'EpgStorage';

  static String cacheFileName(String guideId) =>
      'cinemuse_epg_cache_$guideId.json';

  /// Folder that holds the cache files. Tests pass a temporary folder.
  final Future<Directory> Function() _cacheDirectory;

  EpgStorageService({Future<Directory> Function()? cacheDirectory})
    : _cacheDirectory = cacheDirectory ?? getTemporaryDirectory;

  Future<File> _getCacheFile(String guideId) async {
    final dir = await _cacheDirectory();
    return File('${dir.path}/${cacheFileName(guideId)}');
  }

  /// Loads the guide's cached EPG data if it exists, has not expired and was
  /// saved for [expectedUrl]. Returns `null` when there is no usable cache.
  Future<Map<String, List<EpgProgram>>?> loadCachedEpg(
    String guideId, {
    String? expectedUrl,
    Duration ttl = defaultTtl,
  }) async {
    try {
      final path = (await _getCacheFile(guideId)).path;
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
    String guideId,
    String url,
    Map<String, List<EpgProgram>> epgData,
  ) async {
    try {
      final path = (await _getCacheFile(guideId)).path;
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

  /// Deletes a removed guide's cache file, if there is one.
  Future<void> deleteCachedEpg(String guideId) async {
    try {
      final file = await _getCacheFile(guideId);
      if (file.existsSync()) await file.delete();
    } catch (e, s) {
      // A leftover cache only takes space in the temporary folder.
      AppLogger.warn(
        _tag,
        'Could not delete the EPG cache',
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
  // each list once, under its first (original) key. The keys the parser
  // rebuilds from it are left out; the others go in `channels`: the number
  // as `lcn`, as the Cinemuse guide sends it, the rest (such as the names an
  // XMLTV guide gives a channel) as `aliases`.
  final firstKeys = HashMap<List<EpgProgram>, String>.identity();
  final serializedData = <String, dynamic>{};
  final channels = <String, Map<String, dynamic>>{};
  for (final entry in epg.entries) {
    final firstKey = firstKeys.putIfAbsent(entry.value, () => entry.key);
    if (firstKey == entry.key) {
      serializedData[entry.key] = entry.value.map((p) => p.toJson()).toList();
      continue;
    }
    if (EpgParser.aliasesOf(firstKey).contains(entry.key)) continue;
    final info = channels[firstKey] ??= {};
    final number = EpgParser.numberFromKey(entry.key);
    if (number != null) {
      info['lcn'] = number;
    } else {
      ((info['aliases'] ??= <String>[]) as List<String>).add(entry.key);
    }
  }
  if (channels.isNotEmpty) serializedData['channels'] = channels;

  final payload = {
    'savedAt': DateTime.now().millisecondsSinceEpoch,
    'url': url,
    'data': serializedData,
  };
  File(path).writeAsStringSync(json.encode(payload), flush: true);
}
