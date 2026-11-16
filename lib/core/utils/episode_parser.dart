/// Reads the season and episode from a torrent's or a file's name.
class EpisodeParser {
  // Built once: the parser runs for every file of every torrent.
  static final _seasonEpisode = RegExp(
    r'(?<![a-z0-9])s(\d{1,2})[\s.\-]?e(\d{1,4})(?!\d)',
  );
  static final _crossFormat = RegExp(
    r'(?<![a-z0-9]|\d\.)s?(\d{1,2})x(\d{1,4})(?![a-z0-9])',
  );
  static final _season = RegExp(
    r'(?<![a-z0-9])s(\d{1,2})(?![a-z0-9])|\b(?:season|stagione)[\s.\-]*(\d{1,2})\b',
  );

  /// Numbers that are never an episode: codecs, picture sizes, file sizes.
  static final _notEpisodes = RegExp(
    r'\b[hx][. ]?26[45]\b'
    r'|\b\d{3,4}\s?x\s?\d{3,4}\b'
    r'|\b\d+(?:[.,]\d+)?\s?(?:tb|gb|mb|kb|gib|mib)\b'
    r'|\b\d{1,2}[ .\-]?bit\b'
    r'|\b\d{2,3}\s?fps\b'
    r'|\b\d{3,4}[pi]\b',
  );

  /// From the surest to the least sure. The last one is any lone number, which
  /// can also be part of a title ("Mob Psycho 100").
  static final _absolutePatterns = [
    RegExp(r'\b(?:episodio|episode|ep)[\s.\-]*(\d{1,4})\b'), // "Episodio 5"
    RegExp(r'(?<![a-z0-9])e(\d{1,4})\b'), // "E05"
    RegExp(r'\s-\s(\d{1,4})\b(?!\.\d)'), // " - 5"
    RegExp(r'\[(\d{2,4})\]'), // "[01]"
    RegExp(r'\b(\d{2,4})\b'), // " 01 "
  ];

  static final _seasonRange = RegExp(
    r'(?<![a-z0-9])s(\d{1,2})\s?[\-~]\s?s?(\d{1,2})(?![a-z0-9])'
    r'|\b(?:seasons?|stagioni|stagione)[\s.\-]*(\d{1,2})\s?(?:-|~|to|a)\s?(\d{1,2})\b',
  );

  /// "S01E01-E03", "S01E01-03", "S01E01E02": the episodes of one season. With
  /// spaces it needs the E: in "S10E05 - 201" the second number is the anime's
  /// count from the first episode.
  static final _multiEpisode = RegExp(
    r'(?<![a-z0-9])s\d{1,2}[\s.\-]?e(\d{1,4})(?:-e?|\s-\se|e)(\d{1,4})(?![\dpi])',
  );

  // Word boundaries so codec tags (x265-10bit) and years (1999-2001) don't
  // count as episode ranges, and no more dashes around it so a date doesn't.
  static final _episodeRange = RegExp(
    r'(?<![\d.\-])\b(\d{1,3})(\s?)[\-~](\s?)(\d{1,3})\b(?!-?\d)',
  );

  static final _batch = RegExp(r'\bbatch\b');

  /// These words can be in a title ("A Complete Unknown", "The Collection"),
  /// so they count only for a name that doesn't point at one episode. "pack"
  /// is a whole word: REPACK and Wolfpack are not season packs.
  static final _batchWord = RegExp(r'\b(?:pack|complet[ae]|collection)\b');

  /// Result of parsing a filename for media information.
  /// Includes season, episode, and absolute episode numbers.
  static EpisodeParseResult parse(String filename) {
    final t = _normalise(filename);
    int? season;
    int? episode;

    // 1. Try to find Season and Episode (SxxExx or SxEx)
    final seMatch = _seasonEpisode.firstMatch(t);
    final xMatch = seMatch == null ? _crossFormat.firstMatch(t) : null;
    if (seMatch != null) {
      season = int.tryParse(seMatch.group(1)!);
      episode = int.tryParse(seMatch.group(2)!);
    } else if (xMatch != null) {
      // 2. Try X format (1x01)
      season = int.tryParse(xMatch.group(1)!);
      episode = int.tryParse(xMatch.group(2)!);
    } else if (_findSeasonRange(t) == null) {
      // 3. A season alone ("S02", "Season 2")
      final match = _season.firstMatch(t);
      if (match != null) {
        season = int.tryParse(match.group(1) ?? match.group(2)!);
      }
    }

    // 4. Absolute episode (common in anime): " - 01", "episode 01", "[01]", " 01 "
    var absolute = _findAbsoluteEpisode(t);

    final pointsAtOneEpisode =
        seMatch != null || xMatch != null || absolute?.isSure == true;
    final hasRange =
        _findSeasonRange(t) != null || _findEpisodeRange(t) != null;
    final isBatch =
        _batch.hasMatch(t) ||
        (!pointsAtOneEpisode && _batchWord.hasMatch(t)) ||
        hasRange;

    // In a batch with no range, a lone number belongs to the title.
    if (isBatch && !hasRange && absolute?.isSure == false) absolute = null;

    // If we only found an absolute episode, it's often the "episode" for
    // season 1 or a continuous release.
    episode ??= absolute?.number;

    return EpisodeParseResult(
      season: season,
      episode: episode,
      absoluteEpisode: absolute?.number,
      isBatch: isBatch,
    );
  }

  static String _normalise(String filename) =>
      filename.toLowerCase().replaceAll('_', ' ').replaceAll(_notEpisodes, ' ');

  static ({int number, bool isSure})? _findAbsoluteEpisode(String text) {
    for (var i = 0; i < _absolutePatterns.length; i++) {
      for (final match in _absolutePatterns[i].allMatches(text)) {
        final number = int.parse(match.group(1)!);
        if (!_looksLikeYear(number)) {
          return (number: number, isSure: i < _absolutePatterns.length - 1);
        }
      }
    }
    return null;
  }

  // No show has reached episode 1900, so these numbers are release years.
  static bool _looksLikeYear(int number) => number >= 1900 && number <= 2099;

  static ({int start, int end})? _findSeasonRange(String text) {
    final match = _seasonRange.firstMatch(text);
    if (match == null) return null;
    final start = int.parse(match.group(1) ?? match.group(3)!);
    final end = int.parse(match.group(2) ?? match.group(4)!);
    return start < end ? (start: start, end: end) : null;
  }

  /// The first "start-end" episode range, such as `01-26`. A range that goes
  /// backwards (`100 - 05`) is not one, and neither is a season and its
  /// episode (`Show 2 - 05`, `Show 2-05`): the two numbers of a range are
  /// written alike, unless they touch and the second has no leading zero
  /// (`1-211`).
  static ({int start, int end})? _findEpisodeRange(String text) {
    final multi = _multiEpisode.firstMatch(text);
    if (multi != null) {
      final start = int.parse(multi.group(1)!);
      final end = int.parse(multi.group(2)!);
      if (start < end) return (start: start, end: end);
    }

    final withoutSeasons = text.replaceAll(_seasonRange, ' ');
    for (final match in _episodeRange.allMatches(withoutSeasons)) {
      final first = match.group(1)!;
      final last = match.group(4)!;
      final touching = match.group(2)!.isEmpty && match.group(3)!.isEmpty;
      final writtenAlike =
          first.length == last.length || (touching && !last.startsWith('0'));
      final start = int.parse(first);
      final end = int.parse(last);
      if (writtenAlike && start < end) return (start: start, end: end);
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
      final text = _normalise(filename);

      // The name says which seasons are inside: another one can't be.
      if (targetSeason != null) {
        final seasons = _findSeasonRange(text);
        if (seasons != null) {
          if (targetSeason < seasons.start || targetSeason > seasons.end) {
            return false;
          }
        } else if (parsed.season != null && parsed.season != targetSeason) {
          return false;
        }
      }

      if (parsed.episode == null && parsed.absoluteEpisode == null) return true;
      if (targetEpisode != null && parsed.episode == targetEpisode) return true;
      if (targetAbsoluteEpisode != null &&
          parsed.absoluteEpisode == targetAbsoluteEpisode) {
        return true;
      }

      // If it has an episode but it's different, it might be the start of the batch (e.g. 01-26)
      // Check for range patterns
      final range = _findEpisodeRange(text);
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

class EpisodeParseResult {
  final int? season;
  final int? episode;
  final int? absoluteEpisode;
  final bool isBatch;

  EpisodeParseResult({
    this.season,
    this.episode,
    this.absoluteEpisode,
    this.isBatch = false,
  });

  @override
  String toString() =>
      'EpisodeParseResult(S: $season, E: $episode, Abs: $absoluteEpisode, Batch: $isBatch)';
}
