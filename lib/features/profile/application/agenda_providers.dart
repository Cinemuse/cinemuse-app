import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';

import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/profile/data/agenda_repository.dart';
import 'package:cinemuse_app/features/profile/domain/agenda_event.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final agendaRepositoryProvider = Provider<AgendaRepository>((ref) {
  return AgendaRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(watchHistoryRepositoryProvider),
  );
});

enum AgendaGroup {
  recentlyReleased,
  today,
  tomorrow,
  thisWeek,
  nextWeek,
  later,
  tbd,
}

typedef GroupedAgenda = Map<AgendaGroup, List<AgendaEvent>>;

final agendaProvider = FutureProvider<GroupedAgenda>((ref) async {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return {};

  // Watch these providers to trigger a rebuild when they change
  ref.watch(watchHistoryStreamProvider);
  ref.watch(userListsProvider);

  final repo = ref.watch(agendaRepositoryProvider);

  // 1. Get IDs
  final followed = await repo.getFollowedIds(userId);

  // 2. Read the agenda cache table (movies and episodes together)
  final (movies, episodes) = await (
    repo.fetchUpcomingMovies(followed.movieIds),
    repo.fetchUpcomingEpisodes(followed.seriesIds, followed.seriesHistory),
  ).wait;

  // 3. Completed series with a new episode go back to Continue Watching.
  for (final show in episodes.toReopen) {
    try {
      await repo.reopenSeries(
        userId: userId,
        tmdbId: show.tmdbId,
        season: show.season,
        episode: show.episode,
      );
    } on AppFailure catch (e, s) {
      // The agenda still shows; the next load tries again.
      AppLogger.warn(
        'agendaProvider',
        'Could not put series ${show.tmdbId} back in Continue Watching',
        error: e,
        stackTrace: s,
      );
    }
  }

  final allEvents = [...movies, ...episodes.events];
  allEvents.sort((a, b) => a.releaseDate.compareTo(b.releaseDate));

  return groupEvents(allEvents);
});

/// Sorts [events] into agenda groups, relative to [now] (default: the
/// current time). Boundaries are calendar days, never `+ 24 h`, so the days
/// the clocks change (23 or 25 hours long) group correctly.
@visibleForTesting
GroupedAgenda groupEvents(List<AgendaEvent> events, {DateTime? now}) {
  final groups = <AgendaGroup, List<AgendaEvent>>{
    AgendaGroup.recentlyReleased: [],
    AgendaGroup.today: [],
    AgendaGroup.tomorrow: [],
    AgendaGroup.thisWeek: [],
    AgendaGroup.nextWeek: [],
    AgendaGroup.later: [],
    AgendaGroup.tbd: [],
  };

  final current = now ?? DateTime.now();
  DateTime day(int offset) =>
      DateTime(current.year, current.month, current.day + offset);

  final today = day(0);
  final tomorrow = day(1);
  // Weeks run Monday to Sunday: next Monday starts "next week", the Monday
  // after it starts "later".
  final nextWeekStart = day(8 - current.weekday);
  final laterStart = day(15 - current.weekday);

  // Agenda only shows releases up to 30 days in the past
  final recentlyReleasedCutoff = day(-30);

  for (final event in events) {
    final date = event.releaseDate;
    final dateNoTime = DateTime(date.year, date.month, date.day);

    if (event.isTbd) {
      groups[AgendaGroup.tbd]!.add(event);
    } else if (dateNoTime.isBefore(recentlyReleasedCutoff)) {
      // Released more than 30 days ago - outside agenda scope
      continue;
    } else if (dateNoTime.isBefore(today)) {
      groups[AgendaGroup.recentlyReleased]!.add(event);
    } else if (dateNoTime == today) {
      groups[AgendaGroup.today]!.add(event);
    } else if (dateNoTime == tomorrow) {
      groups[AgendaGroup.tomorrow]!.add(event);
    } else if (dateNoTime.isBefore(nextWeekStart)) {
      groups[AgendaGroup.thisWeek]!.add(event);
    } else if (dateNoTime.isBefore(laterStart)) {
      groups[AgendaGroup.nextWeek]!.add(event);
    } else {
      groups[AgendaGroup.later]!.add(event);
    }
  }

  // Remove empty groups
  groups.removeWhere((key, value) => value.isEmpty);

  return groups;
}
