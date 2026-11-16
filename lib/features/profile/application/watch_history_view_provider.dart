import 'package:cinemuse_app/features/media/application/own_reviews_provider.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/own_review.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/profile/domain/watch_history_filter.dart';
import 'package:cinemuse_app/features/profile/domain/watch_history_view.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The watch logs joined with the live local history, so a title's current
/// status and the watch in progress show. With the logs failing, the local
/// history alone (when there is one); with none, the logs' error.
final watchHistoryEntriesProvider =
    Provider.autoDispose<AsyncValue<List<WatchHistory>>>((ref) {
      final logsAsync = ref.watch(watchLogsProvider);
      final local = ref.watch(watchHistoryStreamProvider).value ?? const [];
      return logsAsync.when(
        data: (logs) => AsyncData(_joinLogsWithLocalHistory(logs, local)),
        loading: () => const AsyncLoading(),
        error: (e, s) => local.isNotEmpty ? AsyncData(local) : AsyncError(e, s),
      );
    });

/// The watch history screen's items, timeline and header counts for one
/// filter. Cached by Riverpod: a screen rebuild (scrolling, focus) redoes
/// none of it (REV-97).
final watchHistoryViewProvider = Provider.autoDispose
    .family<AsyncValue<WatchHistoryView>, WatchHistoryFilter>((ref, filter) {
      final language = ref.watch(settingsProvider.select((s) => s.appLanguage));
      return ref
          .watch(watchHistoryEntriesProvider)
          .whenData(
            (entries) => _buildView(entries, filter, language, DateTime.now()),
          );
    });

/// The Ratings view: the filtered and sorted titles under their scores, highest
/// first. Separate from the view, so a failed read of the ratings leaves the
/// header. Only a finished watch counts: the history also holds titles in
/// progress, whose rating stays hidden.
final watchHistoryRatingsProvider = Provider.autoDispose
    .family<AsyncValue<List<RatingTier>>, WatchHistoryFilter>((ref, filter) {
      final logs = ref.watch(watchLogsProvider);
      if (logs case AsyncError(:final error, :final stackTrace)) {
        return AsyncError(error, stackTrace);
      }
      final items = ref.watch(watchHistoryViewProvider(filter)).value?.items;
      return ref
          .watch(allOwnReviewsProvider)
          .whenData(
            (reviews) => _ratingTiers(items ?? const [], reviews, {
              for (final log in logs.value ?? const <WatchHistory>[])
                log.titleKey,
            }),
          );
    });

List<RatingTier> _ratingTiers(
  List<WatchHistory> items,
  Map<String, OwnReview> reviews,
  Set<String> watched,
) {
  final byScore = <int, List<WatchHistory>>{};
  for (final item in items) {
    final review = reviews[item.titleKey];
    if (review != null && watched.contains(item.titleKey)) {
      byScore.putIfAbsent(review.rating, () => []).add(item);
    }
  }
  final scores = byScore.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final score in scores)
      RatingTier(score: score, titles: byScore[score]!),
  ];
}

List<WatchHistory> _joinLogsWithLocalHistory(
  List<WatchHistory> logs,
  List<WatchHistory> localList,
) {
  if (localList.isEmpty) return logs;

  final localMap = {for (final item in localList) item.titleKey: item};
  final loggedKeys = <String>{};
  final joined = <WatchHistory>[];

  for (final log in logs) {
    loggedKeys.add(log.titleKey);
    final local = localMap[log.titleKey];
    if (local == null) {
      joined.add(log);
      continue;
    }
    joined.add(
      WatchHistory(
        userId: log.userId,
        tmdbId: log.tmdbId,
        mediaType: log.mediaType,
        status: local.status ?? log.status ?? WatchStatus.completed,
        // A log is a finished past watch: the local row's duration belongs
        // to the episode in progress now (REV-103).
        progressSeconds: log.progressSeconds,
        totalDuration: log.totalDuration,
        watchCount: log.watchCount,
        lastWatchedAt: log.lastWatchedAt,
        season: log.season ?? local.season,
        episode: log.episode ?? local.episode,
        media: log.media ?? local.media,
      ),
    );
  }

  for (final local in localList) {
    if (!loggedKeys.contains(local.titleKey)) {
      // In progress or dropped, never finished.
      joined.add(local);
    } else if (local.status == WatchStatus.watching &&
        local.progressSeconds > 0) {
      // The in-progress watch; logs never carry progress.
      joined.add(local);
    }
  }
  return joined;
}

WatchHistoryView _buildView(
  List<WatchHistory> entries,
  WatchHistoryFilter filter,
  String language,
  DateTime now,
) {
  final matching = [
    for (final h in entries)
      if (_matches(h, filter, language)) h,
  ];
  final items = filter.isTimeline
      ? List.of(matching)
      : _newestPerTitle(matching).toList();
  _sort(items, filter.sortOption, language);

  return WatchHistoryView(
    items: items,
    sections: filter.isTimeline
        ? _timelineSections(items, filter.granularity, now)
        : const [],
    counts: _counts(entries, matching),
  );
}

/// Entries without media are never shown.
bool _matches(WatchHistory h, WatchHistoryFilter filter, String language) =>
    h.media != null &&
    (filter.type == null || h.mediaType == filter.type) &&
    (filter.status == null || h.status == filter.status) &&
    (filter.query.isEmpty ||
        (h.media!.getLocalizedTitle(language) ?? '').toLowerCase().contains(
          filter.query,
        ));

/// Each title once, with its latest watch.
Iterable<WatchHistory> _newestPerTitle(Iterable<WatchHistory> items) {
  final newest = <String, WatchHistory>{};
  for (final item in items) {
    final existing = newest[item.titleKey];
    if (existing == null ||
        item.lastWatchedAt.isAfter(existing.lastWatchedAt)) {
      newest[item.titleKey] = item;
    }
  }
  return newest.values;
}

void _sort(List<WatchHistory> items, HistorySortOption sort, String language) {
  switch (sort) {
    case HistorySortOption.recentlyWatched:
      items.sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));
    case HistorySortOption.releaseDate:
      final noDate = DateTime(1970);
      items.sort(
        (a, b) => (b.media?.releaseDate ?? noDate).compareTo(
          a.media?.releaseDate ?? noDate,
        ),
      );
    case HistorySortOption.rating:
      items.sort(
        (a, b) => (b.media?.voteAverage ?? 0.0).compareTo(
          a.media?.voteAverage ?? 0.0,
        ),
      );
    case HistorySortOption.title:
      items.sort(
        (a, b) => (a.media?.getLocalizedTitle(language) ?? '').compareTo(
          b.media?.getLocalizedTitle(language) ?? '',
        ),
      );
  }
}

WatchHistoryCounts _counts(
  List<WatchHistory> entries,
  List<WatchHistory> matching,
) {
  final all = _newestPerTitle(entries.where((h) => h.media != null));
  final filtered = _newestPerTitle(matching);
  final seasons = <String>{};
  final episodes = <String>{};
  for (final item in matching.where((h) => h.mediaType == MediaKind.tv)) {
    if (item.season != null && item.season! > 0) {
      seasons.add('${item.tmdbId}-${item.season}');
    }
    if (item.episode != null) {
      episodes.add('${item.tmdbId}-${item.season}-${item.episode}');
    }
  }
  int countOf(Iterable<WatchHistory> list, MediaKind kind) =>
      list.where((h) => h.mediaType == kind).length;
  return WatchHistoryCounts(
    totalMovies: countOf(all, MediaKind.movie),
    totalSeries: countOf(all, MediaKind.tv),
    filteredMovies: countOf(filtered, MediaKind.movie),
    filteredSeries: countOf(filtered, MediaKind.tv),
    seasons: seasons.length,
    episodes: episodes.length,
  );
}

/// Sections newest first whatever the sort, which applies inside each one
/// (REV-104).
List<TimelineSection> _timelineSections(
  List<WatchHistory> items,
  TimelineGranularity granularity,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final groups = <Object, List<WatchHistory>>{};
  final recentDays = <Object, TimelineRecentDay?>{};
  final dates = <Object, DateTime>{};

  for (final item in items) {
    // The user's day, not the UTC one: a watch at 00:30 is today (REV-312).
    final date = item.lastWatchedAt.toLocal();
    final day = DateTime(date.year, date.month, date.day);
    final recentDay = granularity == TimelineGranularity.daily
        ? _recentDay(day, today)
        : null;
    final period = switch (granularity) {
      TimelineGranularity.daily => day,
      TimelineGranularity.monthly => DateTime(date.year, date.month),
      TimelineGranularity.yearly => DateTime(date.year),
    };
    final Object key = recentDay ?? period;
    groups.putIfAbsent(key, () => []).add(item);
    recentDays[key] = recentDay;
    dates.putIfAbsent(key, () => item.lastWatchedAt);
  }

  // Date ranges don't overlap, so any item dates its section.
  final keys = groups.keys.toList()
    ..sort((a, b) => dates[b]!.compareTo(dates[a]!));
  return [
    for (final key in keys)
      TimelineSection(
        recentDay: recentDays[key],
        date: dates[key]!.toLocal(),
        decks: _decks(groups[key]!),
      ),
  ];
}

TimelineRecentDay? _recentDay(DateTime day, DateTime today) {
  if (day == today) return TimelineRecentDay.today;
  if (day == today.subtract(const Duration(days: 1))) {
    return TimelineRecentDay.yesterday;
  }
  if (day.isAfter(today.subtract(const Duration(days: 7)))) {
    return TimelineRecentDay.thisWeek;
  }
  if (!day.isBefore(DateTime(today.year, today.month))) {
    return TimelineRecentDay.thisMonth;
  }
  return null;
}

/// One card per title, in the order the titles first appear; a series
/// watched several times becomes one deck with its episode range.
List<DeckEntry> _decks(List<WatchHistory> items) {
  final byTitle = <String, List<WatchHistory>>{};
  for (final item in items) {
    byTitle.putIfAbsent(item.titleKey, () => []).add(item);
  }
  return [for (final watches in byTitle.values) _deck(watches)];
}

DeckEntry _deck(List<WatchHistory> watches) {
  watches.sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));
  final top = watches.first;
  if (top.mediaType != MediaKind.tv) return DeckEntry(item: top);
  return DeckEntry(
    item: top,
    stackCount: watches.length,
    episodeLabel: _episodeLabel(watches),
  );
}

EpisodeLabel? _episodeLabel(List<WatchHistory> watches) {
  final episodesBySeason = <int, Set<int>>{};
  for (final w in watches) {
    final season = w.season;
    final episode = w.episode;
    if (season == null || season <= 0 || episode == null || episode <= 0) {
      continue;
    }
    episodesBySeason.putIfAbsent(season, () => <int>{}).add(episode);
  }
  if (episodesBySeason.isEmpty) return null;

  final seasons = episodesBySeason.keys.toList()..sort();
  List<int> episodesOf(int season) =>
      episodesBySeason[season]!.toList()..sort();

  switch (seasons.length) {
    case 1:
      final eps = episodesOf(seasons.first);
      return eps.length == 1
          ? SingleEpisodeLabel(seasons.first, eps.first)
          : EpisodeRangeLabel(seasons.first, eps.first, eps.last);
    case 2:
      return TwoSeasonLabel(
        seasons.first,
        episodesOf(seasons.first).first,
        seasons.last,
        episodesOf(seasons.last).last,
      );
    default:
      return SeasonRangeLabel(seasons.first, seasons.last);
  }
}
