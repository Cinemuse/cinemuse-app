class MediaParser {
  // Built once: the parser runs for every file of every torrent.
  static final _seasonEpisode = RegExp(r's(\d{1,2})\s?e(\d{1,3})');
  static final _crossFormat = RegExp(r'(\d{1,2})x(\d{1,3})');
  static final _absolutePatterns = [
    RegExp(r'\s-\s(\d{2,4})\b'), // " - 01 "
    RegExp(r'episode\s+(\d{1,4})\b'), // "episode 01"
    RegExp(r'\[(\d{2,4})\]'), // "[01]"
    RegExp(r'\b(\d{2,4})\b'), // " 01 " (least specific)
  ];
  static final _seasonRange = RegExp(r's\d{1,2}\s?-\s?s\d{1,2}');
  // Word boundaries so codec tags (x265-10bit) and years (1999-2001) don't
  // count as episode ranges.
  static final _episodeRange = RegExp(r'\b(\d{1,3})\s?-\s?(\d{1,3})\b');

  /// Result of parsing a filename for media information.
  /// Includes season, episode, and absolute episode numbers.
  static MediaParseResult parse(String filename) {
    final t = filename.toLowerCase();
    int? season;
    int? episode;

    // 1. Try to find Season and Episode (SxxExx or SxEx)
    final seMatch = _seasonEpisode.firstMatch(t);
    if (seMatch != null) {
      season = int.tryParse(seMatch.group(1)!);
      episode = int.tryParse(seMatch.group(2)!);
    } else {
      // 2. Try X format (1x01)
      final xMatch = _crossFormat.firstMatch(t);
      if (xMatch != null) {
        season = int.tryParse(xMatch.group(1)!);
        episode = int.tryParse(xMatch.group(2)!);
      }
    }

    // 3. Absolute episode (common in anime): " - 01", "episode 01", "[01]", " 01 "
    final absoluteEpisode = _findAbsoluteEpisode(t);

    // If we only found an absolute episode and no season,
    // it's often the "episode" for season 1 or a continuous release.
    if (season == null && episode == null) {
      episode = absoluteEpisode;
    }

    // Check for Batch/Complete markers
    final isBatch =
        t.contains('batch') ||
        t.contains('complete') ||
        t.contains('collection') ||
        t.contains('pack') ||
        _seasonRange.hasMatch(t) ||
        _findEpisodeRange(t) != null;

    return MediaParseResult(
      season: season,
      episode: episode,
      absoluteEpisode: absoluteEpisode,
      isBatch: isBatch,
    );
  }

  static int? _findAbsoluteEpisode(String text) {
    for (final pattern in _absolutePatterns) {
      for (final match in pattern.allMatches(text)) {
        final number = int.parse(match.group(1)!);
        if (!_looksLikeYear(number)) return number;
      }
    }
    return null;
  }

  // No show has reached episode 1900, so these numbers are release years.
  static bool _looksLikeYear(int number) => number >= 1900 && number <= 2099;

  /// The first "start-end" episode range, such as `01-26`. A range that
  /// goes backwards (`100 - 05`) is not one.
  static ({int start, int end})? _findEpisodeRange(String text) {
    for (final match in _episodeRange.allMatches(text)) {
      final start = int.parse(match.group(1)!);
      final end = int.parse(match.group(2)!);
      if (start < end) return (start: start, end: end);
    }
    return null;
  }

  /// Checks if a filename matches a specific season and episode target.
  static bool matches(
    String filename, {
    int? targetSeason,
    int? targetEpisode,
    int? targetAbsoluteEpisode,
  }) {
    final parsed = parse(filename);

    // If it's a batch/complete, and we don't have a specific CONFLICTING episode,
    // we assume it MIGHT contain the target.
    if (parsed.isBatch) {
      // If the batch title explicitly lists a different episode or range that excludes ours,
      // we should theoretically return false, but usually batches contain everything.
      // For now, if it's a batch and has no specific single episode that conflicts, it's a match.
      if (parsed.episode == null && parsed.absoluteEpisode == null) return true;
      if (targetEpisode != null && parsed.episode == targetEpisode) return true;
      if (targetAbsoluteEpisode != null &&
          parsed.absoluteEpisode == targetAbsoluteEpisode) {
        return true;
      }

      // If it has an episode but it's different, it might be the start of the batch (e.g. 01-26)
      // Check for range patterns
      final range = _findEpisodeRange(filename.toLowerCase());
      if (range != null) {
        if (targetAbsoluteEpisode != null &&
            targetAbsoluteEpisode >= range.start &&
            targetAbsoluteEpisode <= range.end) {
          return true;
        }
        if (targetEpisode != null &&
            targetEpisode >= range.start &&
            targetEpisode <= range.end) {
          return true;
        }
      }

      // If it's a batch but didn't match the range/specific ep, we still allow it as a fallback
      // if it contains "Complete" or "Batch" and NO other episode number is found.
      if (parsed.episode == null) return true;
    }

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
  final bool isBatch;

  MediaParseResult({
    this.season,
    this.episode,
    this.absoluteEpisode,
    this.isBatch = false,
  });

  @override
  String toString() =>
      'MediaParseResult(S: $season, E: $episode, Abs: $absoluteEpisode, Batch: $isBatch)';
}
