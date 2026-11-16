import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';

enum HistoryViewMode { grid, timeline, ratings }

enum TimelineGranularity { daily, monthly, yearly }

enum HistorySortOption { recentlyWatched, releaseDate, rating, title }

/// What the watch history screen shows: the filters, the order and the view.
/// Immutable with value equality, so it can key a provider family.
class WatchHistoryFilter {
  final MediaKind? type;
  final WatchStatus? status;

  /// Trimmed and lower case.
  final String query;
  final HistoryViewMode viewMode;
  final TimelineGranularity granularity;
  final HistorySortOption sortOption;

  const WatchHistoryFilter({
    this.type,
    this.status,
    this.query = '',
    this.viewMode = HistoryViewMode.grid,
    this.granularity = TimelineGranularity.daily,
    this.sortOption = HistorySortOption.recentlyWatched,
  });

  bool get isTimeline => viewMode == HistoryViewMode.timeline;

  bool get isRatings => viewMode == HistoryViewMode.ratings;

  /// The filters changed from their default (the mobile Filters button and
  /// sheet). The granularity counts only in the timeline, where it shows.
  int get activeFilterCount =>
      (type != null ? 1 : 0) +
      (status != null ? 1 : 0) +
      (sortOption != HistorySortOption.recentlyWatched ? 1 : 0) +
      (isTimeline && granularity != TimelineGranularity.daily ? 1 : 0);

  WatchHistoryFilter withType(MediaKind? type) => _copy(type: () => type);

  WatchHistoryFilter withStatus(WatchStatus? status) =>
      _copy(status: () => status);

  WatchHistoryFilter copyWith({
    String? query,
    HistoryViewMode? viewMode,
    TimelineGranularity? granularity,
    HistorySortOption? sortOption,
  }) => _copy(
    query: query,
    viewMode: viewMode,
    granularity: granularity,
    sortOption: sortOption,
  );

  /// Type, status, order and granularity back to their defaults; the search
  /// and the view stay.
  WatchHistoryFilter cleared() =>
      WatchHistoryFilter(query: query, viewMode: viewMode);

  WatchHistoryFilter _copy({
    MediaKind? Function()? type,
    WatchStatus? Function()? status,
    String? query,
    HistoryViewMode? viewMode,
    TimelineGranularity? granularity,
    HistorySortOption? sortOption,
  }) => WatchHistoryFilter(
    type: type != null ? type() : this.type,
    status: status != null ? status() : this.status,
    query: query ?? this.query,
    viewMode: viewMode ?? this.viewMode,
    granularity: granularity ?? this.granularity,
    sortOption: sortOption ?? this.sortOption,
  );

  @override
  bool operator ==(Object other) =>
      other is WatchHistoryFilter &&
      other.type == type &&
      other.status == status &&
      other.query == query &&
      other.viewMode == viewMode &&
      other.granularity == granularity &&
      other.sortOption == sortOption;

  @override
  int get hashCode =>
      Object.hash(type, status, query, viewMode, granularity, sortOption);
}
