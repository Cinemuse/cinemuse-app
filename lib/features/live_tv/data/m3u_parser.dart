import 'dart:convert';

import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_name.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_address.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';

/// Parses M3U playlists into channels. Big playlists take seconds: callers
/// run [parse] on a background isolate (PERF-01).
class M3uParser {
  /// Built once: a big playlist has tens of thousands of lines (REV-123).
  /// Any case, double or single quotes: `TVG-ID='x'` is read too.
  static final _attributeRegexes = {
    for (final name in const [
      'tvg-id',
      'tvg-logo',
      'tvg-name',
      'group-title',
      'provider',
      'quality',
      'tvg-chno',
      'tvg-num',
      'channel-id',
      'cinemuse-ask',
    ])
      name: RegExp(
        '(?:^|\\s)$name=(?:"([^"]*)"|\'([^\']*)\')',
        caseSensitive: false,
      ),
  };

  /// `#EXTINF:` plus the duration and attributes, up to the comma before the
  /// name. Commas inside quoted values don't end it.
  static final _extinfHeaderRegex = RegExp(
    r'''^#EXTINF:[^,"']*(?:(?:"[^"]*"|'[^']*')[^,"']*)*''',
  );

  static const _extgrpPrefix = '#EXTGRP:';

  /// VLC's per-channel options: `#EXTVLCOPT:http-referrer=https://…`.
  static const _vlcOptPrefix = '#EXTVLCOPT:';

  /// TiviMate's per-channel headers: `#EXTHTTP:{"Referer":"https://…"}`.
  static const _extHttpPrefix = '#EXTHTTP:';

  /// The VLC options that are headers.
  static const _vlcHeaderOptions = {
    'http-referrer',
    'http-referer',
    'http-user-agent',
    'http-origin',
  };

  static List<Channel> parse(String content, {int startLcn = 2000}) {
    final lines = content.split('\n');
    final channelsByKey = <String, _ParsedChannelBuilder>{};
    final orderedKeys = <String>[];
    int currentLcn = startLcn;

    String? currentName;
    String? currentLogo;
    String? currentGroup;
    // `#EXTGRP:` line, used when there is no `group-title` (REV-123).
    String? currentExtGrp;
    String? currentEpgId;
    String? currentProvider;
    String? currentQuality;
    String? currentAsk;
    int? currentChno;
    // Header lines may come before or after `#EXTINF`: kept until the link.
    var currentHeaders = <String, String>{};

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        currentEpgId = _extractAttribute(line, 'tvg-id');
        currentLogo = _extractAttribute(line, 'tvg-logo');
        currentGroup = _extractAttribute(line, 'group-title');
        currentProvider = _extractAttribute(line, 'provider');
        currentQuality = _extractAttribute(line, 'quality');
        currentAsk = _extractAttribute(line, 'cinemuse-ask');
        currentName = _extractChannelName(line);
        final chnoStr =
            _extractAttribute(line, 'tvg-chno') ??
            _extractAttribute(line, 'tvg-num') ??
            _extractAttribute(line, 'channel-id');
        currentChno = int.tryParse(chnoStr ?? '');
      } else if (line.startsWith(_extgrpPrefix)) {
        final group = line.substring(_extgrpPrefix.length).trim();
        currentExtGrp = group.isEmpty ? null : group;
      } else if (line.startsWith(_vlcOptPrefix)) {
        _readVlcOption(line.substring(_vlcOptPrefix.length), currentHeaders);
      } else if (line.startsWith(_extHttpPrefix)) {
        _readExtHttp(line.substring(_extHttpPrefix.length), currentHeaders);
      } else if (!line.startsWith('#')) {
        if (currentName != null) {
          final url = _readPipeHeaders(line, currentHeaders);
          final key = ChannelName.rowId(currentName, currentEpgId);
          final quality = _parseQuality(currentQuality, currentName, url);
          final link = StreamLink(
            url: url,
            quality: quality,
            provider: currentProvider,
            ask: currentAsk,
            headers: Map.unmodifiable(currentHeaders),
          );

          final explicitLcn = (currentChno != null && currentChno > 0)
              ? currentChno
              : null;

          if (channelsByKey.containsKey(key)) {
            final builder = channelsByKey[key]!;
            builder.addLink(link);
            if (explicitLcn != null && builder.lcn >= startLcn) {
              builder.lcn = explicitLcn;
            }
          } else {
            final builder = _ParsedChannelBuilder(
              lcn: explicitLcn ?? currentLcn++,
              name: currentName,
              logo: currentLogo ?? '',
              group: currentGroup ?? currentExtGrp,
              epgId: currentEpgId,
              initialLink: link,
            );
            channelsByKey[key] = builder;
            orderedKeys.add(key);
          }
        }

        currentName = null;
        currentLogo = null;
        currentGroup = null;
        currentExtGrp = null;
        currentEpgId = null;
        currentProvider = null;
        currentQuality = null;
        currentAsk = null;
        currentChno = null;
        currentHeaders = {};
      }
    }

    return orderedKeys.map((k) => channelsByKey[k]!.build()).toList();
  }

  static void _readVlcOption(String option, Map<String, String> headers) {
    final equals = option.indexOf('=');
    if (equals <= 0) return;
    final name = option.substring(0, equals).trim().toLowerCase();
    final value = option.substring(equals + 1).trim();
    if (!_vlcHeaderOptions.contains(name) || value.isEmpty) return;
    headers[StreamLink.headerName(name)] = value;
  }

  static void _readExtHttp(String jsonText, Map<String, String> headers) {
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } on FormatException {
      // A broken line loses only its headers: the channel still plays.
      return;
    }
    if (decoded is! Map) return;
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (entry.key is String && value is String && value.isNotEmpty) {
        headers[StreamLink.headerName(entry.key as String)] = value;
      }
    }
  }

  /// Kodi's form, `https://…/live.m3u8|Referer=https://…&User-Agent=…`:
  /// returns the link without the tail and adds the tail's headers. The tail
  /// is never sent as part of the address.
  static String _readPipeHeaders(String line, Map<String, String> headers) {
    final pipe = line.indexOf('|');
    if (pipe < 0) return line;
    for (final pair in line.substring(pipe + 1).split('&')) {
      final equals = pair.indexOf('=');
      if (equals <= 0) continue;
      final value = _decodeOrRaw(pair.substring(equals + 1).trim());
      if (value.isEmpty) continue;
      headers[StreamLink.headerName(pair.substring(0, equals))] = value;
    }
    return line.substring(0, pipe).trim();
  }

  /// Kodi escapes the values (`Mozilla%2F5.0`); a value that isn't escaped
  /// properly is used as written.
  static String _decodeOrRaw(String value) {
    try {
      return Uri.decodeComponent(value);
    } on ArgumentError {
      return value;
    }
  }

  /// The name is everything after the comma that ends the attributes, so a
  /// name like "Rai 1, HD" keeps its own comma (REV-123).
  static String _extractChannelName(String line) {
    final headerEnd = _extinfHeaderRegex.firstMatch(line)?.end ?? 0;
    if (headerEnd < line.length && line[headerEnd] == ',') {
      final name = line.substring(headerEnd + 1).trim();
      if (name.isNotEmpty) return name;
    }
    return _extractAttribute(line, 'tvg-name') ?? 'Unknown Channel';
  }

  static StreamQuality _parseQuality(
    String? qualityAttr,
    String name,
    String url,
  ) {
    if (qualityAttr != null && qualityAttr.trim().isNotEmpty) {
      final q = qualityAttr.trim().toUpperCase();
      if (q == '4K' || q == 'UHD') return StreamQuality.uhd;
      if (q == 'FHD' || q == '1080P' || q == '1080') return StreamQuality.fhd;
      if (q == 'HD' || q == '720P' || q == '720') return StreamQuality.hd;
      if (q == 'SD' || q == '576P' || q == '480P') return StreamQuality.sd;
    }
    return _detectQuality(name, url);
  }

  static StreamQuality _detectQuality(String name, String url) {
    final upperName = name.toUpperCase();

    if (upperName.contains('4K') || upperName.contains('UHD')) {
      return StreamQuality.uhd;
    }
    if (upperName.contains('FHD') || upperName.contains('1080')) {
      return StreamQuality.fhd;
    }
    if (upperName.contains('HD') ||
        upperName.contains('720') ||
        StreamAddress(url).isRawTs) {
      return StreamQuality.hd;
    }
    return StreamQuality.sd;
  }

  static String? _extractAttribute(String line, String attributeName) {
    final match = _attributeRegexes[attributeName]!.firstMatch(line);
    return match?.group(1) ?? match?.group(2);
  }
}

class _ParsedChannelBuilder {
  int lcn;
  final String name;
  final String logo;
  final String? group;
  final String? epgId;
  final List<StreamLink> _links;

  _ParsedChannelBuilder({
    required this.lcn,
    required this.name,
    required this.logo,
    this.group,
    this.epgId,
    required StreamLink initialLink,
  }) : _links = [initialLink];

  void addLink(StreamLink link) {
    // Avoid exact duplicate URLs
    if (!_links.any((l) => l.url == link.url)) {
      _links.add(link);
    }
  }

  Channel build() {
    return Channel(
      lcn: lcn,
      name: name,
      logo: logo,
      group: group,
      epgId: epgId,
      links: List.unmodifiable(_links),
    );
  }
}
