import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';

class M3uParser {
  static List<Channel> parse(String content, {int startLcn = 2000}) {
    final lines = content.split('\n');
    final channels = <Channel>[];
    int currentLcn = startLcn;

    String? currentName;
    String? currentLogo;
    String? currentGroup;
    String? currentEpgId;

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        // Parse metadata
        currentEpgId = _extractAttribute(line, 'tvg-id');
        currentLogo = _extractAttribute(line, 'tvg-logo');
        currentGroup = _extractAttribute(line, 'group-title');

        // Extract name (after the last comma)
        final commaIndex = line.lastIndexOf(',');
        if (commaIndex != -1 && commaIndex + 1 < line.length) {
          currentName = line.substring(commaIndex + 1).trim();
        } else {
          currentName = _extractAttribute(line, 'tvg-name') ?? 'Unknown Channel';
        }
      } else if (!line.startsWith('#')) {
        // This is the URL line
        if (currentName != null) {
          final channel = Channel(
            lcn: currentLcn++,
            name: currentName,
            logo: currentLogo ?? '',
            group: currentGroup,
            epgId: currentEpgId,
            links: [StreamLink(url: line)],
          );
          channels.add(channel);
        }
        
        // Reset for next entry
        currentName = null;
        currentLogo = null;
        currentGroup = null;
        currentEpgId = null;
      }
    }

    return channels;
  }

  static String? _extractAttribute(String line, String attributeName) {
    final regex = RegExp('$attributeName="([^"]*)"');
    final match = regex.firstMatch(line);
    return match?.group(1);
  }
}
