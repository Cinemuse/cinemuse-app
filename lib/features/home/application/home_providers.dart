import 'dart:async';
import 'dart:math';

import 'package:cinemuse_app/core/data/server_addresses_model.dart';
import 'package:cinemuse_app/core/data/server_addresses_repository.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/media/application/watch_history_store.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:cinemuse_app/features/home/domain/sport_tv_event.dart';
import 'package:cinemuse_app/features/home/data/sport_schedule_scraper.dart';
import 'package:cinemuse_app/features/settings/application/watch_region_providers.dart';
import 'package:cinemuse_app/features/media/application/own_reviews_provider.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
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
  // Read, not watched: a watch would keep a failed download (offline, no
  // saved copy) alive for every scraper instead of trying it again.
  final sites = await ref.read(serverAddressesProvider.future);
  final pageUrl = sites.address(ServerAddress.sportSchedule);
  if (pageUrl == null) {
    AppLogger.warn('SportSchedule', 'No sport schedule address in the list');
    return const [];
  }
  final events = await SportScheduleScraper(dio).fetchSchedule(pageUrl);
  return upcomingSportEvents(events, DateTime.now());
});

// Home's TMDB rows live for the whole session: Home keeps them while the
// user is on other tabs.
final trendingProvider = FutureProvider<List<MediaItem>>((ref) async {
  final tmdbService = ref.watch(tmdbServiceProvider);
  return tmdbService.getTrending();
});

final moviesInTheatersProvider = FutureProvider<List<MediaItem>>((ref) {
  final tmdb = ref.watch(tmdbServiceProvider);
  return tmdb.getMoviesInTheaters(ref.watch(watchRegionProvider));
});

final newMoviesOnStreamingProvider = FutureProvider<List<MediaItem>>((ref) {
  final tmdb = ref.watch(tmdbServiceProvider);
  return tmdb.getNewMoviesOnStreaming(
    ref.watch(watchRegionProvider),
    DateTime.now(),
  );
});

final newSeriesProvider = FutureProvider<List<MediaItem>>((ref) {
  return ref.watch(tmdbServiceProvider).getNewSeries(DateTime.now());
});

final topRatedRecentSeriesProvider = FutureProvider<List<MediaItem>>((ref) {
  return ref.watch(tmdbServiceProvider).getTopRatedRecentSeries(DateTime.now());
});

/// The titles finished or dropped (by `titleKey`): Home's TMDB rows and its
/// slideshow leave them out.
final seenTitleKeysProvider = Provider.autoDispose<Set<String>>((ref) {
  final history = ref.watch(shownWatchHistoryProvider).value ?? const {};
  return {
    for (final MapEntry(:key, :value) in history.entries)
      if (value.status == WatchStatus.completed ||
          value.status == WatchStatus.dropped)
        key,
  };
});

/// A Home row's titles: [source]'s without the ones finished or dropped.
final unseenHomeTitlesProvider = Provider.autoDispose
    .family<AsyncValue<List<MediaItem>>, FutureProvider<List<MediaItem>>>((
      ref,
      source,
    ) {
      final seen = ref.watch(seenTitleKeysProvider);
      return ref
          .watch(source)
          .whenData(
            (titles) => [
              for (final title in titles)
                if (!seen.contains('${title.mediaType.name}-${title.tmdbId}'))
                  title,
            ],
          );
    });

final continueWatchingProvider = Provider<AsyncValue<List<WatchHistory>>>((
  ref,
) {
  final historyMapAsync = ref.watch(shownWatchHistoryProvider);

  return historyMapAsync.whenData((historyMap) {
    // One row per title already (REV-195): a movie and a show sharing a
    // tmdbId are both kept.
    final list = historyMap.values
        .where((item) => item.status == WatchStatus.watching)
        .toList();
    list.sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));
    return list;
  });
});

/// A title rated this or more counts as loved, like a Favourite.
const lovedRating = 8;

/// The titles Home's "like X" rows can start from: the Favourites and the
/// titles rated [lovedRating] or more (their name and poster come from the
/// watch history, since only a watched title can be rated).
final lovedTitlesProvider = Provider.autoDispose<List<MediaItem>>((ref) {
  final lists = ref.watch(userListsProvider).value ?? const [];
  final favourites =
      lists.where((l) => l.type == ListType.favorites).firstOrNull?.items ??
      const [];
  final ratings = ref.watch(allOwnReviewsProvider).value ?? const {};
  final history = ref.watch(shownWatchHistoryProvider).value ?? const {};
  // By titleKey, so a Favourite that is also rated counts once.
  final loved = <String, MediaItem>{
    for (final review in ratings.values)
      if (review.rating >= lovedRating)
        review.titleKey: ?history[review.titleKey]?.media,
    for (final item in favourites)
      '${item.mediaType.name}-${item.tmdbId}': ?item.media,
  };
  return loved.values.toList();
});

/// Where the "like X" rows pick at random; a provider so tests can fix it.
final lovedPickRandomProvider = Provider<Random>((ref) => Random());

/// The loved film and the loved series Home's two "like X" rows start from.
typedef LovedPicks = ({MediaItem? film, MediaItem? series});

/// One loved film and one loved series, picked at random. A pick stays while
/// it is still loved, so a change to the lists doesn't swap the rows under
/// the user; [pickAgain] (Home's pull to refresh) picks others. Lives for the
/// whole session, like Home's TMDB rows.
final lovedPicksProvider = NotifierProvider<LovedPicksNotifier, LovedPicks>(
  LovedPicksNotifier.new,
);

class LovedPicksNotifier extends Notifier<LovedPicks> {
  @override
  LovedPicks build() {
    final loved = ref.watch(lovedTitlesProvider);
    final before = stateOrNull;
    return (
      film: _pick(loved, MediaKind.movie, keep: before?.film),
      series: _pick(loved, MediaKind.tv, keep: before?.series),
    );
  }

  /// Picks another film and another series, when there is another.
  void pickAgain() {
    final loved = ref.read(lovedTitlesProvider);
    state = (
      film: _pick(loved, MediaKind.movie, avoid: state.film),
      series: _pick(loved, MediaKind.tv, avoid: state.series),
    );
  }

  MediaItem? _pick(
    List<MediaItem> loved,
    MediaKind kind, {
    MediaItem? keep,
    MediaItem? avoid,
  }) {
    bool same(MediaItem a, MediaItem? b) =>
        b != null && a.tmdbId == b.tmdbId && a.mediaType == b.mediaType;

    final candidates = loved.where((t) => t.mediaType == kind).toList();
    if (keep != null && candidates.any((t) => same(t, keep))) return keep;
    final others = candidates.where((t) => !same(t, avoid)).toList();
    final from = others.isEmpty ? candidates : others;
    if (from.isEmpty) return null;
    return from[ref.read(lovedPickRandomProvider).nextInt(from.length)];
  }
}

/// TMDB's suggestions for the loved film ([MediaKind.movie]) or series
/// ([MediaKind.tv]); empty when there is none. Lives for the whole session,
/// like Home's TMDB rows.
final lovedSuggestionsProvider =
    FutureProvider.family<List<MediaItem>, MediaKind>((ref, kind) async {
      final loved = ref.watch(
        lovedPicksProvider.select(
          (p) => kind == MediaKind.movie ? p.film : p.series,
        ),
      );
      if (loved == null) return const [];
      return ref
          .watch(tmdbServiceProvider)
          .getSuggestions(loved.mediaType, loved.tmdbId);
    });
