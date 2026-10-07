class PersonSeenStats {
  final int watchedCount;
  final int totalReleased;
  final int watchedPercent;

  const PersonSeenStats({
    required this.watchedCount,
    required this.totalReleased,
    required this.watchedPercent,
  });

  const PersonSeenStats.empty()
      : watchedCount = 0,
        totalReleased = 0,
        watchedPercent = 0;
}

/// Domain service handling person credits, stats, and filmography filtering.
class PersonDomainService {
  static const Set<int> excludedGenreIds = {99, 10763, 10764, 10767};
  static const List<String> excludedKeywords = [
    'academy awards',
    'golden globe',
    'oscar',
    'grammy',
    'emmy',
    'mtv movie awards',
    'bafta',
    'award',
  ];

  /// Calculates watched statistics across released items in cast and crew credits.
  static PersonSeenStats calculateSeenStats({
    required List<dynamic> cast,
    required List<dynamic> crew,
    required Map<String, dynamic> watchHistory,
    DateTime? referenceDate,
  }) {
    int watchedCount = 0;
    int totalReleased = 0;
    final now = referenceDate ?? DateTime.now();

    final allCredits = [...cast, ...crew];
    final seenIds = <int>{};

    for (final item in allCredits) {
      if (item is! Map) continue;
      final id = item['id'] as int?;
      if (id == null || seenIds.contains(id)) continue;
      seenIds.add(id);

      final dateStr = (item['release_date'] ?? item['first_air_date'])?.toString();
      if (dateStr != null && dateStr.isNotEmpty) {
        final releaseDate = DateTime.tryParse(dateStr);
        if (releaseDate != null && releaseDate.isBefore(now)) {
          totalReleased++;
          if (watchHistory.containsKey(id.toString())) {
            watchedCount++;
          }
        }
      }
    }

    final watchedPercent = totalReleased > 0
        ? (watchedCount / totalReleased * 100).round()
        : 0;

    return PersonSeenStats(
      watchedCount: watchedCount,
      totalReleased: totalReleased,
      watchedPercent: watchedPercent,
    );
  }

  /// Extracts the top known-for works based on vote count.
  static List<Map<String, dynamic>> extractTopKnownFor(
    List<dynamic> cast, {
    int limit = 10,
  }) {
    final knownFor = cast
        .whereType<Map<String, dynamic>>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList()
      ..sort((a, b) => (b['vote_count'] ?? 0).compareTo(a['vote_count'] ?? 0));
    return knownFor.take(limit).toList();
  }

  /// Deduplicates cast and crew, sorts by date descending, and applies hidden filters if requested.
  static List<Map<String, dynamic>> processFilmography({
    required List<dynamic> cast,
    required List<dynamic> crew,
    required bool showHidden,
  }) {
    final uniqueCreditsMap = <int, Map<String, dynamic>>{};

    for (final item in [...cast, ...crew]) {
      if (item is! Map) continue;
      final id = item['id'] as int?;
      if (id != null && !uniqueCreditsMap.containsKey(id)) {
        uniqueCreditsMap[id] = Map<String, dynamic>.from(item);
      }
    }

    var filmography = uniqueCreditsMap.values.toList();

    // Sort Date DESC
    filmography.sort((a, b) {
      final dateA = (a['release_date'] ?? a['first_air_date'] ?? '0000-00-00').toString();
      final dateB = (b['release_date'] ?? b['first_air_date'] ?? '0000-00-00').toString();
      return dateB.compareTo(dateA);
    });

    if (!showHidden) {
      filmography = filmography.where((item) {
        final genreIds =
            (item['genre_ids'] as List<dynamic>?)?.whereType<int>().toSet() ??
                <int>{};
        final hasExcludedGenre = genreIds.any(
          (id) => excludedGenreIds.contains(id),
        );

        final title = (item['title'] ?? item['name'] ?? '')
            .toString()
            .toLowerCase();
        final hasExcludedKeyword = excludedKeywords.any(
          (kw) => title.contains(kw),
        );

        return !hasExcludedGenre && !hasExcludedKeyword;
      }).toList();
    }

    return filmography;
  }
}
