import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';

class M3uParser {
  /// Extracts the EPG / TV guide URL from the #EXTM3U header if present.
  /// Looks for attributes like url-tvg="..." or x-tvg-url="...".
  static String? extractEpgUrl(String content) {
    final lines = content.split('\n');
    for (var i = 0; i < lines.length && i < 15; i++) {
      final line = lines[i].trim();
      if (line.startsWith('#EXTM3U')) {
        final urlTvg =
            _extractAttribute(line, 'url-tvg') ??
            _extractAttribute(line, 'x-tvg-url');
        if (urlTvg != null && urlTvg.trim().isNotEmpty) {
          return urlTvg.trim();
        }
      }
    }
    return null;
  }

  static List<Channel> parse(String content, {int startLcn = 2000}) {
    final lines = content.split('\n');
    final channelsByKey = <String, _ParsedChannelBuilder>{};
    final orderedKeys = <String>[];
    int currentLcn = startLcn;

    String? currentName;
    String? currentLogo;
    String? currentGroup;
    String? currentEpgId;
    String? currentProvider;
    String? currentQuality;
    int? currentChno;

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        currentEpgId = _extractAttribute(line, 'tvg-id');
        currentLogo = _extractAttribute(line, 'tvg-logo');
        currentGroup = _extractAttribute(line, 'group-title');
        currentProvider = _extractAttribute(line, 'provider');
        currentQuality = _extractAttribute(line, 'quality');
        currentName = _extractChannelName(line);
        final chnoStr =
            _extractAttribute(line, 'tvg-chno') ??
            _extractAttribute(line, 'tvg-num') ??
            _extractAttribute(line, 'channel-id');
        currentChno = int.tryParse(chnoStr ?? '');
      } else if (!line.startsWith('#')) {
        if (currentName != null) {
          final key = _buildChannelKey(currentEpgId, currentName);
          final quality = _parseQuality(currentQuality, currentName, line);
          final link = StreamLink(
            url: line,
            quality: quality,
            provider: currentProvider,
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
              group: currentGroup,
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
        currentEpgId = null;
        currentProvider = null;
        currentQuality = null;
        currentChno = null;
      }
    }

    return orderedKeys.map((k) => channelsByKey[k]!.build()).toList();
  }

  static String _extractChannelName(String line) {
    final commaIndex = line.lastIndexOf(',');
    if (commaIndex != -1 && commaIndex + 1 < line.length) {
      return line.substring(commaIndex + 1).trim();
    }
    return _extractAttribute(line, 'tvg-name') ?? 'Unknown Channel';
  }

  static String _buildChannelKey(String? epgId, String name) {
    if (epgId != null && epgId.trim().isNotEmpty) {
      return 'epg:${epgId.trim().toLowerCase()}';
    }
    return 'name:${name.trim().toLowerCase()}';
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
    final upperUrl = url.toUpperCase();

    if (upperName.contains('4K') || upperName.contains('UHD')) {
      return StreamQuality.uhd;
    }
    if (upperName.contains('FHD') || upperName.contains('1080')) {
      return StreamQuality.fhd;
    }
    if (upperName.contains('HD') ||
        upperName.contains('720') ||
        upperUrl.contains('.TS')) {
      return StreamQuality.hd;
    }
    return StreamQuality.sd;
  }

  static String? _extractAttribute(String line, String attributeName) {
    final regex = RegExp('$attributeName="([^"]*)"');
    final match = regex.firstMatch(line);
    return match?.group(1);
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
