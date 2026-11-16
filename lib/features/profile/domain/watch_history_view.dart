import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/profile/domain/watch_history_filter.dart';

/// Everything the watch history screen shows for one [WatchHistoryFilter].
class WatchHistoryView {
  /// Filtered and sorted. Grid: one entry per title; timeline: every watch.
  final List<WatchHistory> items;

  /// Newest first; empty in the grid.
  final List<TimelineSection> sections;
  final WatchHistoryCounts counts;

  const WatchHistoryView({
    required this.items,
    required this.sections,
    required this.counts,
  });
}

/// The header's numbers. Only what this screen loaded, never the server
/// stats (REV-269).
class WatchHistoryCounts {
  final int totalMovies;
  final int totalSeries;
  final int filteredMovies;
  final int filteredSeries;

  /// Distinct seasons and episodes of the filtered series, rewatches counted
  /// once (REV-102).
  final int seasons;
  final int episodes;

  const WatchHistoryCounts({
    required this.totalMovies,
    required this.totalSeries,
    required this.filteredMovies,
    required this.filteredSeries,
    required this.seasons,
    required this.episodes,
  });

  int get totalTitles => totalMovies + totalSeries;
  int get filteredTitles => filteredMovies + filteredSeries;
}

/// The titles the user gave one score, in the screen's order.
class RatingTier {
  final int score;
  final List<WatchHistory> titles;

  const RatingTier({required this.score, required this.titles});
}

/// The recent days the daily timeline names instead of showing a date.
enum TimelineRecentDay { today, yesterday, thisWeek, thisMonth }

/// One timeline header and its cards.
class TimelineSection {
  /// Set only in the daily view, for the recent days.
  final TimelineRecentDay? recentDay;

  /// Any date in the section: the screen shows its day, month or year.
  final DateTime date;
  final List<DeckEntry> decks;

  const TimelineSection({
    required this.recentDay,
    required this.date,
    required this.decks,
  });
}

/// One card: a title's newest watch in the section, with how many watches
/// of the same series it stands for.
class DeckEntry {
  final WatchHistory item;

  /// More than 1 only for a series watched several times in the section.
  final int stackCount;
  final EpisodeLabel? episodeLabel;

  const DeckEntry({required this.item, this.stackCount = 1, this.episodeLabel});
}

/// The episodes a card stands for, shown on the card ("S1 E2–E5").
sealed class EpisodeLabel {
  const EpisodeLabel();
}

/// "S1 E2".
class SingleEpisodeLabel extends EpisodeLabel {
  final int season;
  final int episode;
  const SingleEpisodeLabel(this.season, this.episode);
}

/// "S1 E2–E5".
class EpisodeRangeLabel extends EpisodeLabel {
  final int season;
  final int first;
  final int last;
  const EpisodeRangeLabel(this.season, this.first, this.last);
}

/// "S1 E8–S2 E3".
class TwoSeasonLabel extends EpisodeLabel {
  final int firstSeason;
  final int firstEpisode;
  final int lastSeason;
  final int lastEpisode;
  const TwoSeasonLabel(
    this.firstSeason,
    this.firstEpisode,
    this.lastSeason,
    this.lastEpisode,
  );
}

/// "S1–S4".
class SeasonRangeLabel extends EpisodeLabel {
  final int firstSeason;
  final int lastSeason;
  const SeasonRangeLabel(this.firstSeason, this.lastSeason);
}
