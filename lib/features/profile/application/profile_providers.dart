import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/profile/data/profile_repository.dart';
import 'package:cinemuse_app/features/profile/domain/profile.dart';
import 'package:cinemuse_app/features/profile/domain/profile_stats.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. Current User ID Provider
final userIdProvider = Provider<String?>((ref) {
  final user = ref.watch(authProvider).valueOrNull;
  return user?.id;
});

// 2. Profile Stream Provider (Real-time updates from DB)
final profileStreamProvider = StreamProvider<Profile?>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return Stream.value(null);

  return supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', userId)
      .map((event) {
        if (event.isEmpty) return null;
        return Profile.fromJson(event.first);
      });
});

// 3. Watch History Stream Provider (All history for stats)
final watchHistoryStreamProvider = StreamProvider<List<WatchHistory>>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return Stream.value([]);
  
  return ref.watch(watchHistoryRepositoryProvider).watchAllHistory(userId)
      .handleError((error, stackTrace) {
    // On expired JWT or channel errors, return empty list.
    // The session refresh will eventually trigger a rebuild via authProvider.
    if (error is RealtimeSubscribeException) {
      return <WatchHistory>[];
    }
    throw error;
  });
});

// 4. Computed Stats Provider (Fetching from Supabase View)
final profileStatsProvider = StreamProvider<ProfileStats>((ref) async* {
  final userId = ref.watch(userIdProvider);
  if (userId == null) {
    yield ProfileStats.empty();
    return;
  }

  // Local database stream acts as an invalidator trigger
  // Every time a user watches something, the local watch_histories table is merged/updated,
  // triggering this stream, which in turn fetches the true aggregated stats from backend.
  final localStream = ref.watch(watchHistoryStreamProvider.stream);
  
  // Initial fetch and subsequent re-fetches
  await for (final _ in localStream) {
    try {
      final res = await supabase.from('user_stats').select().eq('user_id', userId).maybeSingle();
      if (res == null) {
        yield ProfileStats.empty();
        continue;
      }
      
      yield ProfileStats(
          totalMinutesWatched: (res['total_minutes_watched'] as num?)?.toInt() ?? 0,
          totalEpisodes: (res['total_episodes'] as num?)?.toInt() ?? 0,
          totalMovies: (res['total_movies'] as num?)?.toInt() ?? 0,
          totalSeries: (res['total_series'] as num?)?.toInt() ?? 0,
          totalSeasons: (res['total_seasons'] as num?)?.toInt() ?? 0,
          last7Days: PeriodStats(
            totalMinutes: (res['p7_minutes'] as num?)?.toInt() ?? 0,
            movieCount: (res['p7_movies'] as num?)?.toInt() ?? 0,
            episodeCount: (res['p7_episodes'] as num?)?.toInt() ?? 0,
          ),
          last30Days: PeriodStats(
            totalMinutes: (res['p30_minutes'] as num?)?.toInt() ?? 0,
            movieCount: (res['p30_movies'] as num?)?.toInt() ?? 0,
            episodeCount: (res['p30_episodes'] as num?)?.toInt() ?? 0,
          ),
          last365Days: PeriodStats(
            totalMinutes: (res['p365_minutes'] as num?)?.toInt() ?? 0,
            movieCount: (res['p365_movies'] as num?)?.toInt() ?? 0,
            episodeCount: (res['p365_episodes'] as num?)?.toInt() ?? 0,
          ),
          movieMinutes: (res['movie_minutes'] as num?)?.toInt() ?? 0,
          seriesMinutes: (res['series_minutes'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      // Return empty stats on failure or keep previous
      yield ProfileStats.empty();
    }
  }
});
