class MediaParser {
  /// Result of parsing a filename for media information.
  /// Includes season, episode, and absolute episode numbers.
  static MediaParseResult parse(String filename) {
    final t = filename.toLowerCase();
    int? season;
    int? episode;
    int? absoluteEpisode;

    // 1. Try to find Season and Episode (SxxExx or SxEx)
    final seMatch = RegExp(
      r's(\d{1,2})\s?e(\d{1,3})',
      caseSensitive: false,
    ).firstMatch(t);
    if (seMatch != null) {
      season = int.tryParse(seMatch.group(1)!);
      episode = int.tryParse(seMatch.group(2)!);
    } else {
      // 2. Try X format (1x01)
      final xMatch = RegExp(
        r'(\d{1,2})x(\d{1,3})',
        caseSensitive: false,
      ).firstMatch(t);
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
      RegExp(r'\s-\s(\d{2,4})\b'), // " - 01 "
      RegExp(r'episode\s+(\d{1,4})\b'), // "episode 01"
      RegExp(r'\[(\d{2,4})\]'), // "[01]"
      RegExp(r'\b(\d{2,4})\b'), // " 01 " (least specific)
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

    // Check for Batch/Complete markers
    final isBatch =
        t.contains('batch') ||
        t.contains('complete') ||
        t.contains('collection') ||
        t.contains('pack') ||
        RegExp(r's\d{1,2}\s?-\s?s\d{1,2}', caseSensitive: false).hasMatch(t) ||
        RegExp(r'\d{1,3}\s?-\s?\d{1,3}', caseSensitive: false).hasMatch(t);

    return MediaParseResult(
      season: season,
      episode: episode,
      absoluteEpisode: absoluteEpisode,
      isBatch: isBatch,
    );
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
          parsed.absoluteEpisode == targetAbsoluteEpisode)
        return true;

      // If it has an episode but it's different, it might be the start of the batch (e.g. 01-26)
      // Check for range patterns
      final rangeMatch = RegExp(
        r'(\d{1,3})\s?-\s?(\d{1,3})',
      ).firstMatch(filename);
      if (rangeMatch != null) {
        final start = int.tryParse(rangeMatch.group(1)!);
        final end = int.tryParse(rangeMatch.group(2)!);
        if (start != null && end != null) {
          if (targetAbsoluteEpisode != null &&
              targetAbsoluteEpisode >= start &&
              targetAbsoluteEpisode <= end)
            return true;
          if (targetEpisode != null &&
              targetEpisode >= start &&
              targetEpisode <= end)
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
