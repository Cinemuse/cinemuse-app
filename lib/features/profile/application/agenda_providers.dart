import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/core/services/media/tmdb_service.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/media/application/watch_history_store.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/profile/data/agenda_repository.dart';
import 'package:cinemuse_app/features/profile/domain/agenda_event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final agendaRepositoryProvider = Provider<AgendaRepository>((ref) {
  return AgendaRepository(
    supabase, 
    ref.watch(tmdbServiceProvider),
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
  
  // 2. Fetch from TMDB & Sync New Episodes
  final movies = await repo.fetchUpcomingMovies(followed.keys.contains(MediaKind.movie) ? followed[MediaKind.movie]! : {});
  final episodes = await repo.fetchUpcomingEpisodes(
    userId,
    followed.keys.contains(MediaKind.tv) ? followed[MediaKind.tv]! : {},
  );
  
  final allEvents = [...movies, ...episodes];
  allEvents.sort((a, b) => a.releaseDate.compareTo(b.releaseDate));
  
  return _groupEvents(allEvents);
});

GroupedAgenda _groupEvents(List<AgendaEvent> events) {
  final groups = <AgendaGroup, List<AgendaEvent>>{
    AgendaGroup.recentlyReleased: [],
    AgendaGroup.today: [],
    AgendaGroup.tomorrow: [],
    AgendaGroup.thisWeek: [],
    AgendaGroup.nextWeek: [],
    AgendaGroup.later: [],
    AgendaGroup.tbd: [],
  };

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  
  // End of this week (Sunday)
  final daysUntilSunday = 7 - today.weekday;
  final endOfThisWeek = today.add(Duration(days: daysUntilSunday, hours: 23, minutes: 59, seconds: 59));
  
  // Next week boundaries
  final nextWeekStart = endOfThisWeek.add(const Duration(seconds: 1));
  final nextWeekEnd = nextWeekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

  for (final event in events) {
    final date = event.releaseDate;
    final dateNoTime = DateTime(date.year, date.month, date.day);

    if (event.isTbd) {
      groups[AgendaGroup.tbd]!.add(event);
    } else if (dateNoTime.isBefore(today)) {
      groups[AgendaGroup.recentlyReleased]!.add(event);
    } else if (dateNoTime == today) {
      groups[AgendaGroup.today]!.add(event);
    } else if (dateNoTime == tomorrow) {
      groups[AgendaGroup.tomorrow]!.add(event);
    } else if (date.isBefore(endOfThisWeek)) {
      groups[AgendaGroup.thisWeek]!.add(event);
    } else if (date.isAfter(endOfThisWeek) && date.isBefore(nextWeekEnd)) {
      groups[AgendaGroup.nextWeek]!.add(event);
    } else {
      groups[AgendaGroup.later]!.add(event);
    }
  }

  // Remove empty groups
  groups.removeWhere((key, value) => value.isEmpty);
  
  return groups;
}
