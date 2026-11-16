import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_name.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:xml/xml.dart' show XmlParserException;
import 'package:xml/xml_events.dart';

/// Parser for EPG feeds in JSON, XMLTV, and Gzipped XMLTV formats.
///
/// Parsing a full guide takes seconds: callers run it on a background
/// isolate (PERF-01). Lines logged from there don't reach
/// [AppLogger.recent] of the main isolate, only the console.
class EpgParser {
  static const _tag = 'EpgParser';

  /// `+0200`, `-0130` or `+02:00` after the 14 date digits (LTV-04).
  static final _offsetRegex = RegExp(r'^([+-])(\d{2}):?(\d{2})');

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

  /// Parses JSON EPG structure (e.g. from Cinemuse edge function). Entries
  /// that aren't programme lists are skipped, except `channels`.
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

    _registerChannels(result, json['channels']);
    return result;
  }

  /// The key under which a channel number's programmes are found.
  static String numberKey(int number) => 'lcn:$number';

  /// The channel number in a [numberKey], or null for any other key.
  static int? numberFromKey(String key) =>
      key.startsWith('lcn:') ? int.tryParse(key.substring(4)) : null;

  /// A guide's `channels` (`{"rai1": {"name": "Rai 1", "lcn": 1}}`). `lcn`
  /// is the channel's number, so a playlist channel matched by nothing but
  /// its number still finds its programmes. `aliases` are the other keys
  /// that lead to it, such as the names an XMLTV guide gives it: the saved
  /// copy keeps them there.
  static void _registerChannels(
    Map<String, List<EpgProgram>> map,
    dynamic channels,
  ) {
    if (channels is! Map) return;
    for (final entry in channels.entries) {
      final info = entry.value;
      final programs = map[entry.key.toString().trim()];
      if (info is! Map || programs == null) continue;
      final number = info['lcn'];
      if (number is int && number > 0) {
        map.putIfAbsent(numberKey(number), () => programs);
      }
      final aliases = info['aliases'];
      if (aliases is List) {
        for (final alias in aliases.whereType<String>()) {
          if (alias.isNotEmpty) map.putIfAbsent(alias, () => programs);
        }
      }
    }
  }

  /// Parses standard XMLTV XML content into channel EPG entries. A broken
  /// spot is skipped and reading goes on after it, so one bad line never
  /// loses the rest of the guide.
  static Map<String, List<EpgProgram>> parseXmltv(String xmlContent) {
    final reader = _XmltvReader();
    final events = parseEvents(xmlContent, withLocation: true).iterator;
    var brokenSpots = 0;
    // Where the XML reader tries next: after the last piece, or after the
    // character it skipped.
    var next = 0;
    while (true) {
      try {
        if (!events.moveNext()) break;
      } on XmlParserException {
        // The XML reader skips the character it stopped on: a "<" written
        // as plain text, as in "Love <3". Keep it in the text being read.
        brokenSpots++;
        reader.addSkipped(xmlContent[next++]);
        continue;
      }
      next = events.current.stop!;
      reader.add(events.current);
    }
    reader.finish();
    if (brokenSpots > 0) {
      AppLogger.warn(
        _tag,
        'Skipped $brokenSpots broken spots in an XMLTV guide',
      );
    }

    final result = reader.programmes;
    for (final key in result.keys.toList()) {
      final programs = result[key]!;
      _sortPrograms(programs);
      _registerAliases(result, key, programs);
    }
    // After every id, so a name never takes the place of a channel's id.
    for (final MapEntry(key: id, value: names) in reader.names.entries) {
      final programs = result[id];
      if (programs == null) continue;
      for (final name in names) {
        _registerAliases(result, name, programs);
      }
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

      // With or without a space before it (LTV-04).
      final tz = _offsetRegex.firstMatch(clean.substring(14).trimLeft());
      if (tz != null) {
        final sign = tz.group(1) == '-' ? -1 : 1;
        final tzHour = int.parse(tz.group(2)!);
        final tzMinute = int.parse(tz.group(3)!);
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

  static void _sortPrograms(List<EpgProgram> programs) {
    programs.sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// Registers lowercased and stripped aliases in the map without overriding existing keys.
  static void _registerAliases(
    Map<String, List<EpgProgram>> map,
    String originalKey,
    List<EpgProgram> programs,
  ) {
    for (final alias in aliasesOf(originalKey)) {
      map.putIfAbsent(alias, () => programs);
    }
  }

  /// The keys a guide key is also found by: lowercased, and stripped to
  /// letters and digits. The saved copy leaves them out: they are rebuilt.
  static List<String> aliasesOf(String key) => [
    key.toLowerCase(),
    ChannelName.guideKey(key),
  ].where((alias) => alias.isNotEmpty).toList();
}

/// Reads an XMLTV guide one piece at a time: the programmes by channel id,
/// and the names each `<channel>` gives its id.
class _XmltvReader {
  final programmes = <String, List<EpgProgram>>{};
  final names = <String, List<String>>{};

  _OpenProgramme? _programme;
  String? _channelId;

  /// The element whose text is being read, if any.
  String? _field;
  final _text = StringBuffer();

  void add(XmlEvent event) {
    switch (event) {
      case XmlStartElementEvent():
        _start(event);
      case XmlEndElementEvent(:final name):
        _end(name);
      // Text outside the fields is never decoded: most of it is spaces.
      case XmlTextEvent() when _field != null:
        _text.write(event.value);
      case XmlCDATAEvent() when _field != null:
        _text.write(event.value);
      default:
    }
  }

  void addSkipped(String character) {
    if (_field != null) _text.write(character);
  }

  /// Keeps a last programme the guide never closed.
  void finish() => _finishProgramme();

  void _start(XmlStartElementEvent event) {
    final programme = _programme;
    switch (event.name) {
      case 'programme':
        // A programme left open ends where the next one starts.
        _finishProgramme();
        if (event.isSelfClosing) return;
        _programme = _OpenProgramme(
          channel: _attribute(event, 'channel'),
          start: _attribute(event, 'start'),
          stop: _attribute(event, 'stop'),
        );
      case 'channel':
        _channelId = event.isSelfClosing ? null : _attribute(event, 'id');
      case 'title' || 'sub-title' || 'desc'
          when programme != null && !event.isSelfClosing:
        _readText(event.name);
      case 'display-name' when _channelId != null && !event.isSelfClosing:
        _readText(event.name);
      case 'icon' when programme != null:
        programme.icon ??= _attribute(event, 'src');
    }
  }

  void _end(String name) {
    if (name == _field) {
      final text = _text.toString().trim();
      _field = null;
      _keepText(name, text);
    } else if (name == 'programme') {
      _finishProgramme();
    } else if (name == 'channel') {
      _channelId = null;
    }
  }

  void _readText(String field) {
    _field = field;
    _text.clear();
  }

  /// The first title, sub-title and description count, as in other readers.
  void _keepText(String field, String text) {
    final programme = _programme;
    final channelId = _channelId;
    switch (field) {
      case 'title' when programme != null:
        programme.title ??= text;
      case 'sub-title' when programme != null:
        programme.subtitle ??= text;
      case 'desc' when programme != null:
        programme.description ??= text;
      case 'display-name' when channelId != null && text.isNotEmpty:
        (names[channelId] ??= []).add(text);
    }
  }

  void _finishProgramme() {
    final open = _programme;
    _programme = null;
    _field = null;
    if (open == null) return;

    final channel = open.channel;
    final title = open.title;
    if (channel == null || title == null || title.isEmpty) return;
    final start = _date(open.start);
    final stop = _date(open.stop);
    if (start == null || stop == null) return;

    (programmes[channel] ??= []).add(
      EpgProgram(
        name: title,
        startTime: start,
        endTime: stop,
        subtitle: _orNull(open.subtitle),
        description: _orNull(open.description),
        imageUrl: _orNull(open.icon),
      ),
    );
  }

  static DateTime? _date(String? text) =>
      text == null ? null : EpgParser.parseXmltvDate(text);

  static String? _orNull(String? text) =>
      text == null || text.isEmpty ? null : text;

  /// The attribute's trimmed value, or null when it is missing or empty.
  static String? _attribute(XmlStartElementEvent event, String name) {
    for (final attribute in event.attributes) {
      if (attribute.name == name) return _orNull(attribute.value.trim());
    }
    return null;
  }
}

/// A `<programme>` being read.
class _OpenProgramme {
  _OpenProgramme({this.channel, this.start, this.stop});

  final String? channel;
  final String? start;
  final String? stop;
  String? title;
  String? subtitle;
  String? description;
  String? icon;
}
