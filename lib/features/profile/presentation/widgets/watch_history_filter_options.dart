import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/profile/domain/watch_history_filter.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// One choice of a watch history filter: the screen's pills, the sort menu
/// and the phone's filter sheet all build from these lists (REV-110).
class FilterOption<T> {
  final T value;
  final String Function(AppLocalizations l10n) label;
  final IconData? icon;

  const FilterOption(this.value, this.label, {this.icon});
}

final List<FilterOption<MediaKind?>> typeOptions = [
  FilterOption(null, (l) => l.watchHistoryAll, icon: Icons.grid_view_rounded),
  FilterOption(
    MediaKind.movie,
    (l) => l.searchMovies,
    icon: Icons.movie_outlined,
  ),
  FilterOption(MediaKind.tv, (l) => l.searchSeries, icon: Icons.tv_outlined),
];

final List<FilterOption<WatchStatus?>> statusOptions = [
  FilterOption(null, (l) => l.watchHistoryStatusAll),
  FilterOption(
    WatchStatus.watching,
    (l) => l.watchHistoryStatusWatching,
    icon: Icons.play_circle_outline_rounded,
  ),
  FilterOption(
    WatchStatus.completed,
    (l) => l.watchHistoryStatusCompleted,
    icon: Icons.check_circle_outline_rounded,
  ),
  FilterOption(
    WatchStatus.dropped,
    (l) => l.watchHistoryStatusDropped,
    icon: Icons.cancel_outlined,
  ),
];

final List<FilterOption<HistorySortOption>> sortOptions = [
  FilterOption(
    HistorySortOption.recentlyWatched,
    (l) => l.watchHistorySortRecent,
    icon: Icons.access_time_rounded,
  ),
  FilterOption(
    HistorySortOption.releaseDate,
    (l) => l.searchNewestReleases,
    icon: Icons.calendar_today_rounded,
  ),
  FilterOption(
    HistorySortOption.rating,
    (l) => l.searchHighestRated,
    icon: Icons.star_outline_rounded,
  ),
  FilterOption(
    HistorySortOption.title,
    (l) => l.watchHistorySortTitle,
    icon: Icons.sort_by_alpha_rounded,
  ),
];

final List<FilterOption<TimelineGranularity>> granularityOptions = [
  FilterOption(
    TimelineGranularity.daily,
    (l) => l.watchHistoryGranularityDaily,
  ),
  FilterOption(
    TimelineGranularity.monthly,
    (l) => l.watchHistoryGranularityMonthly,
  ),
  FilterOption(
    TimelineGranularity.yearly,
    (l) => l.watchHistoryGranularityYearly,
  ),
];

final List<FilterOption<HistoryViewMode>> viewModeOptions = [
  FilterOption(
    HistoryViewMode.grid,
    (l) => l.watchHistoryViewGrid,
    icon: Icons.grid_view_rounded,
  ),
  FilterOption(
    HistoryViewMode.timeline,
    (l) => l.watchHistoryViewTimeline,
    icon: Icons.view_timeline_rounded,
  ),
  FilterOption(
    HistoryViewMode.ratings,
    (l) => l.watchHistoryViewRatings,
    icon: Icons.eco_rounded,
  ),
];
