class MediaParser {
  /// Result of parsing a filename for media information.
  /// Includes season, episode, and absolute episode numbers.
  static MediaParseResult parse(String filename) {
    final t = filename.toLowerCase();
    int? season;
    int? episode;
    int? absoluteEpisode;

    // 1. Try to find Season and Episode (SxxExx or SxEx)
    final seMatch = RegExp(r's(\d{1,2})\s?e(\d{1,3})', caseSensitive: false).firstMatch(t);
    if (seMatch != null) {
      season = int.tryParse(seMatch.group(1)!);
      episode = int.tryParse(seMatch.group(2)!);
    } else {
      // 2. Try X format (1x01)
      final xMatch = RegExp(r'(\d{1,2})x(\d{1,3})', caseSensitive: false).firstMatch(t);
      if (xMatch != null) {
        season = int.tryParse(xMatch.group(1)!);
        episode = int.tryParse(xMatch.group(2)!);
      }
    }

    // 3. Try Absolute Episode Patterns (common in anime)
    // - 01 (standalone if not SxEx)
    // - Episode 01
    // - - 01
    // - [01]
    
    // We only look for absolute episode if season/episode wasn't found or as a fallback
    final absPatterns = [
      RegExp(r'\s-\s(\d{2,4})\b'),          // " - 01 "
      RegExp(r'episode\s+(\d{1,4})\b'),      // "episode 01"
      RegExp(r'\[(\d{2,4})\]'),             // "[01]"
      RegExp(r'\b(\d{2,4})\b'),             // " 01 " (least specific)
    ];

    for (final pattern in absPatterns) {
      final match = pattern.firstMatch(t);
      if (match != null) {
        absoluteEpisode = int.tryParse(match.group(1)!);
        break;
      }
    }

    // If we only found an absolute episode and no season, 
    // it's often the "episode" for season 1 or a continuous release.
    if (season == null && episode == null) {
      episode = absoluteEpisode;
    }

    return MediaParseResult(
      season: season,
      episode: episode,
      absoluteEpisode: absoluteEpisode,
    );
  }

  /// Checks if a filename matches a specific season and episode target.
  static bool matches(String filename, {int? targetSeason, int? targetEpisode, int? targetAbsoluteEpisode}) {
    final parsed = parse(filename);

    // If we have a target absolute episode, it's the strongest signal for anime
    if (targetAbsoluteEpisode != null && parsed.absoluteEpisode != null) {
      if (parsed.absoluteEpisode == targetAbsoluteEpisode) return true;
    }

    // Season match (if both present)
    if (targetSeason != null && parsed.season != null) {
      if (targetSeason != parsed.season) return false;
    }

    // Episode match
    if (targetEpisode != null && parsed.episode != null) {
      if (targetEpisode == parsed.episode) return true;
    }

    return false;
  }
}

class MediaParseResult {
  final int? season;
  final int? episode;
  final int? absoluteEpisode;

  MediaParseResult({this.season, this.episode, this.absoluteEpisode});

  @override
  String toString() => 'MediaParseResult(S: $season, E: $episode, Abs: $absoluteEpisode)';
}
