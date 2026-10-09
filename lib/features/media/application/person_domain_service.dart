import 'package:cinemuse_app/features/media/domain/person.dart';

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
    required List<PersonCredit> cast,
    required List<PersonCredit> crew,
    required Map<String, Object?> watchHistory,
    DateTime? referenceDate,
  }) {
    int watchedCount = 0;
    int totalReleased = 0;
    final now = referenceDate ?? DateTime.now();

    final allCredits = [...cast, ...crew];
    final seenIds = <int>{};

    for (final item in allCredits) {
      final id = item.id;
      if (id <= 0 || seenIds.contains(id)) continue;
      seenIds.add(id);

      final releaseDate = item.releaseDate;
      if (releaseDate != null && releaseDate.isBefore(now)) {
        totalReleased++;
        if (watchHistory.containsKey(id.toString())) {
          watchedCount++;
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
  static List<PersonCredit> extractTopKnownFor(
    List<PersonCredit> cast, {
    int limit = 10,
  }) {
    final knownFor = List<PersonCredit>.from(cast)
      ..sort((a, b) => b.voteCount.compareTo(a.voteCount));
    return knownFor.take(limit).toList();
  }

  /// Deduplicates cast and crew, sorts by date descending, and applies hidden filters if requested.
  static List<PersonCredit> processFilmography({
    required List<PersonCredit> cast,
    required List<PersonCredit> crew,
    required bool showHidden,
  }) {
    final uniqueCreditsMap = <int, PersonCredit>{};

    for (final item in [...cast, ...crew]) {
      final id = item.id;
      if (id > 0 && !uniqueCreditsMap.containsKey(id)) {
        uniqueCreditsMap[id] = item;
      }
    }

    var filmography = uniqueCreditsMap.values.toList();

    // Sort Date DESC
    filmography.sort((a, b) {
      if (a.releaseDate == null && b.releaseDate == null) return 0;
      if (a.releaseDate == null) return 1;
      if (b.releaseDate == null) return -1;
      return b.releaseDate!.compareTo(a.releaseDate!);
    });

    if (!showHidden) {
      filmography = filmography.where((item) {
        final hasExcludedGenre = item.genreIds.any(
          (id) => excludedGenreIds.contains(id),
        );

        final title = item.title.toLowerCase();
        final hasExcludedKeyword = excludedKeywords.any(
          (kw) => title.contains(kw),
        );

        return !hasExcludedGenre && !hasExcludedKeyword;
      }).toList();
    }

    return filmography;
  }
}
