import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';

/// Parser for EPG feeds in JSON, XMLTV, and Gzipped XMLTV formats.
///
/// Parsing a full guide takes seconds: callers run it on a background
/// isolate (PERF-01). Lines logged from there don't reach
/// [AppLogger.recent] of the main isolate, only the console.
class EpgParser {
  static const _tag = 'EpgParser';

  static final _programmeRegex = RegExp(
    r'<programme\s+([^>]+)>(.*?)</programme>',
    caseSensitive: false,
    dotAll: true,
  );
  static final _startRegex = RegExp(r'start="([^"]+)"', caseSensitive: false);
  static final _stopRegex = RegExp(r'stop="([^"]+)"', caseSensitive: false);
  static final _channelRegex = RegExp(
    r'channel="([^"]+)"',
    caseSensitive: false,
  );
  static final _titleRegex = RegExp(
    r'<title[^>]*>(.*?)</title>',
    caseSensitive: false,
    dotAll: true,
  );
  static final _subTitleRegex = RegExp(
    r'<sub-title[^>]*>(.*?)</sub-title>',
    caseSensitive: false,
    dotAll: true,
  );
  static final _descRegex = RegExp(
    r'<desc[^>]*>(.*?)</desc>',
    caseSensitive: false,
    dotAll: true,
  );
  static final _iconRegex = RegExp(
    r'<icon[^>]+src="([^"]+)"',
    caseSensitive: false,
  );
  static final _domainSuffixRegex = RegExp(r'\.it$|\.ch$|\.com$|\.eu$');
  static final _nonAlphanumericRegex = RegExp(r'[^a-z0-9]');

  /// Parses raw byte data into a unified channel EPG map.
  /// Automatically decompresses GZip if magic bytes are detected.
  static Map<String, List<EpgProgram>> parseBytes(Uint8List bytes) {
    if (bytes.isEmpty) return {};

    Uint8List raw = bytes;
    if (_isGzip(bytes)) {
      try {
        final decompressed = GZipDecoder().decodeBytes(bytes);
        // Avoid a second full copy of a guide that can be 100 MB.
        raw = decompressed is Uint8List
            ? decompressed
            : Uint8List.fromList(decompressed);
      } catch (e, s) {
        // Some servers send the gzip magic bytes on plain text.
        AppLogger.warn(
          _tag,
          'GZip decompression failed, falling back to raw bytes',
          error: e,
          stackTrace: s,
        );
        raw = bytes;
      }
    }

    final content = utf8.decode(raw, allowMalformed: true).trim();
    if (content.startsWith('{') || content.startsWith('[')) {
      try {
        final decoded = json.decode(content);
        return parseJson(decoded);
      } catch (e) {
        // Not valid JSON: the feed may still be XMLTV, so try that next.
        AppLogger.debug(_tag, 'EPG is not JSON, trying XMLTV: $e');
      }
    }

    return parseXmltv(content);
  }

  /// Parses JSON EPG structure (e.g. from Cinemuse edge function).
  static Map<String, List<EpgProgram>> parseJson(dynamic json) {
    final Map<String, List<EpgProgram>> result = {};
    if (json is! Map) return result;

    for (final entry in json.entries) {
      final key = entry.key.toString().trim();
      final value = entry.value;
      if (value is! List) continue;

      final programs = <EpgProgram>[];
      for (final item in value) {
        if (item is Map<String, dynamic>) {
          try {
            programs.add(EpgProgram.fromJson(item));
          } catch (e, s) {
            // One bad entry must not drop the whole guide.
            AppLogger.warn(
              _tag,
              'Failed to parse EPG program entry for key: $key',
              error: e,
              stackTrace: s,
            );
          }
        } else if (item is Map) {
          try {
            programs.add(EpgProgram.fromJson(Map<String, dynamic>.from(item)));
          } catch (e, s) {
            // One bad entry must not drop the whole guide.
            AppLogger.warn(
              _tag,
              'Failed to parse EPG program map entry for key: $key',
              error: e,
              stackTrace: s,
            );
          }
        }
      }

      if (programs.isNotEmpty) {
        _sortPrograms(programs);
        result[key] = programs;
        _registerAliases(result, key, programs);
      }
    }

    return result;
  }

  /// Parses standard XMLTV XML content into channel EPG entries.
  static Map<String, List<EpgProgram>> parseXmltv(String xmlContent) {
    final Map<String, List<EpgProgram>> result = {};
    if (xmlContent.isEmpty) return result;

    for (final match in _programmeRegex.allMatches(xmlContent)) {
      final attributes = match.group(1) ?? '';
      final inner = match.group(2) ?? '';

      final channelId = _channelRegex.firstMatch(attributes)?.group(1)?.trim();
      final startStr = _startRegex.firstMatch(attributes)?.group(1)?.trim();
      final stopStr = _stopRegex.firstMatch(attributes)?.group(1)?.trim();

      if (channelId == null || startStr == null || stopStr == null) continue;

      final start = parseXmltvDate(startStr);
      final stop = parseXmltvDate(stopStr);
      if (start == null || stop == null) continue;

      final rawTitle = _titleRegex.firstMatch(inner)?.group(1);
      if (rawTitle == null || rawTitle.trim().isEmpty) continue;

      final title = _unescapeXml(rawTitle.trim());
      final subtitle = _cleanOptionalString(
        _subTitleRegex.firstMatch(inner)?.group(1),
      );
      final desc = _cleanOptionalString(_descRegex.firstMatch(inner)?.group(1));
      final iconUrl = _iconRegex.firstMatch(inner)?.group(1)?.trim();

      final program = EpgProgram(
        name: title,
        startTime: start,
        endTime: stop,
        subtitle: subtitle,
        description: desc,
        imageUrl: iconUrl,
      );

      (result[channelId] ??= []).add(program);
    }

    // Sort programs and register normalized aliases
    final originalKeys = result.keys.toList();
    for (final key in originalKeys) {
      final programs = result[key]!;
      _sortPrograms(programs);
      _registerAliases(result, key, programs);
    }

    return result;
  }

  /// Parses XMLTV format datetime strings, e.g. "20261003120000 +0200" or ISO-8601.
  static DateTime? parseXmltvDate(String dateStr) {
    final clean = dateStr.trim();
    if (clean.length < 14) {
      return DateTime.tryParse(clean);
    }

    // Standard XMLTV format: yyyyMMddHHmmss [+/-HHMM]
    try {
      final year = int.parse(clean.substring(0, 4));
      final month = int.parse(clean.substring(4, 6));
      final day = int.parse(clean.substring(6, 8));
      final hour = int.parse(clean.substring(8, 10));
      final minute = int.parse(clean.substring(10, 12));
      final second = int.parse(clean.substring(12, 14));

      if (clean.length >= 19 && (clean[15] == '+' || clean[15] == '-')) {
        final sign = clean[15] == '-' ? -1 : 1;
        final tzHour = int.parse(clean.substring(16, 18));
        final tzMinute = int.parse(clean.substring(18, 20));
        final offset = Duration(hours: tzHour, minutes: tzMinute) * sign;

        final utcBase = DateTime.utc(year, month, day, hour, minute, second);
        return utcBase.subtract(offset).toLocal();
      }

      return DateTime(year, month, day, hour, minute, second);
    } catch (_) {
      return DateTime.tryParse(clean);
    }
  }

  static bool _isGzip(List<int> bytes) {
    return bytes.length >= 2 && bytes[0] == 0x1F && bytes[1] == 0x8B;
  }

  static String _unescapeXml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }

  static String? _cleanOptionalString(String? text) {
    if (text == null) return null;
    final cleaned = _unescapeXml(text.trim());
    return cleaned.isEmpty ? null : cleaned;
  }

  static void _sortPrograms(List<EpgProgram> programs) {
    programs.sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// Registers lowercased and stripped aliases in the map without overriding existing keys.
  static void _registerAliases(
    Map<String, List<EpgProgram>> map,
    String originalKey,
    List<EpgProgram> programs,
  ) {
    final lowerKey = originalKey.toLowerCase();
    if (!map.containsKey(lowerKey)) {
      map[lowerKey] = programs;
    }

    final strippedKey = lowerKey
        .replaceAll(_domainSuffixRegex, '')
        .replaceAll(_nonAlphanumericRegex, '');
    if (strippedKey.isNotEmpty && !map.containsKey(strippedKey)) {
      map[strippedKey] = programs;
    }
  }
}
