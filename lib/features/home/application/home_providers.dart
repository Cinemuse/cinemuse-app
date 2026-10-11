import 'dart:async';

import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/media/application/watch_history_store.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:cinemuse_app/features/home/domain/sport_tv_event.dart';
import 'package:cinemuse_app/features/home/data/sport_schedule_scraper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long after its start an event stays in the schedule. The site gives no
/// end time, so this covers a match plus extra time.
const sportEventVisibleFor = Duration(hours: 3);

/// How often the schedule is downloaded again while the app stays open
/// (on TV there is no pull-to-refresh).
const _sportScheduleRefreshEvery = Duration(hours: 1);

/// Drops events that started more than [sportEventVisibleFor] before [now]
/// and sorts the rest by start time (events without a time go last).
List<SportTvEvent> upcomingSportEvents(
  List<SportTvEvent> events,
  DateTime now,
) {
  final cutoff = now.subtract(sportEventVisibleFor);
  final upcoming = events
      .where((e) => e.dateTime == null || e.dateTime!.isAfter(cutoff))
      .toList();
  upcoming.sort((a, b) {
    if (a.dateTime == null) return 1;
    if (b.dateTime == null) return -1;
    return a.dateTime!.compareTo(b.dateTime!);
  });
  return upcoming;
}

final sportScheduleProvider = FutureProvider<List<SportTvEvent>>((ref) async {
  final timer = Timer(_sportScheduleRefreshEvery, ref.invalidateSelf);
  ref.onDispose(timer.cancel);

  final dio = ref.watch(dioProvider);
  final events = await SportScheduleScraper(dio).fetchSchedule();
  return upcomingSportEvents(events, DateTime.now());
});

final trendingProvider = FutureProvider<List<MediaItem>>((ref) async {
  final tmdbService = ref.watch(tmdbServiceProvider);
  return tmdbService.getTrending();
});

final popularMoviesProvider = FutureProvider<List<MediaItem>>((ref) async {
  final tmdbService = ref.watch(tmdbServiceProvider);
  return tmdbService.getPopularMovies();
});

final popularSeriesProvider = FutureProvider<List<MediaItem>>((ref) async {
  final tmdbService = ref.watch(tmdbServiceProvider);
  return tmdbService.getPopularSeries();
});

final continueWatchingProvider = Provider<AsyncValue<List<WatchHistory>>>((
  ref,
) {
  final historyMapAsync = ref.watch(watchHistoryStoreProvider);

  return historyMapAsync.whenData((historyMap) {
    // 1. Group by tmdbId and find the latest entry for each
    final latestByTmdbId = <int, WatchHistory>{};

    for (final item in historyMap.values) {
      final existing = latestByTmdbId[item.tmdbId];
      if (existing == null ||
          item.lastWatchedAt.isAfter(existing.lastWatchedAt)) {
        latestByTmdbId[item.tmdbId] = item;
      }
    }

    // 2. Filter these LATEST entries to only keep those currently being watched
    final list = latestByTmdbId.values
        .where((item) => item.status == WatchStatus.watching)
        .toList();

    // 3. Sort by last watched (descending)
    list.sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));
    return list;
  });
});
