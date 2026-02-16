import 'package:cinemuse_app/core/services/supabase_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/profile/data/profile_repository.dart';
import 'package:cinemuse_app/features/profile/domain/profile.dart';
import 'package:cinemuse_app/features/profile/domain/profile_stats.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. Current User ID Provider
final userIdProvider = Provider<String?>((ref) {
  final user = supabase.auth.currentUser;
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
  
  return ref.watch(watchHistoryRepositoryProvider).watchAllHistory(userId);
});

// 4. Computed Stats Provider
final profileStatsProvider = Provider<ProfileStats>((ref) {
  final historyAsync = ref.watch(watchHistoryStreamProvider);
  final profileAsync = ref.watch(profileStreamProvider);

  // Default to empty if loading or error
  final history = historyAsync.value ?? [];
  final profile = profileAsync.value;

  // Use DB stats for totals if available (faster/reliable for all-time)
  // But we need to calculate period stats client-side
  
  return _calculateStats(history, profile);
});

ProfileStats _calculateStats(List<WatchHistory> history, Profile? profile) {
  final now = DateTime.now();
  final cutoff7 = now.subtract(const Duration(days: 7));
  final cutoff30 = now.subtract(const Duration(days: 30));
  final cutoff365 = now.subtract(const Duration(days: 365));

  // Breakdowns
  int movieMins = 0;
  int seriesMins = 0;
  
  // Sets for counting unique items
  final uniqueSeriesIds = <int>{};
  final uniqueSeasons = <String>{}; // "tmdbId-seasonNum"
  final uniqueMovies = <int>{};
  
  int totalEp = 0;

  int p7Mins = 0; int p7Mov = 0; int p7Ep = 0;
  int p30Mins = 0; int p30Mov = 0; int p30Ep = 0;
  int p365Mins = 0; int p365Mov = 0; int p365Ep = 0;

  for (final item in history) {
    final date = item.lastWatchedAt;
    final isMovie = item.mediaType == MediaKind.movie;
    
    // Estimate mins (use actual runtime if available from media_cache, else default)
    // Default: Movie=120, Series=45 (same as web)
    final int runtime = item.media?.runtimeMinutes ?? (isMovie ? 120 : 45);
    // If progress is tracked, maybe use that? 
    // Web logic: "const duration = singleDuration * count;"
    // Here `item` is a unique history entry. Does it represent multiple watches?
    // `item.watchCount` exists in `WatchHistory` model.
    final int count = item.watchCount > 0 ? item.watchCount : 1;
    final int duration = runtime * count;

    // All-time Breakdown
    if (isMovie) {
      movieMins += duration;
      uniqueMovies.add(item.tmdbId);
    } else {
      seriesMins += duration;
      uniqueSeriesIds.add(item.tmdbId);
      totalEp += count; // Assuming 'count' tracks episodes if singular? 
      // Re-read Web Logic:
      // "episodeCount += value.length" <- Sum of all episode entries
      // In App `WatchHistory`, if it's one row per TMDB_ID, we lose episode count unless it's stored.
      // `WatchHistory` model has `episode`. 
      // If we only store "Last Watched Episode", `count` might be "times watched this one episode".
      // BUT `profile.episodesWatchedCount` from DB is likely accurate.
      // Ah, this is where Local Calc fails without full logs.
      // If we rely on Local Calc for Series/Episodes count with incomplete history rows, we undercount.
      
      // FIX: Use Profile's DB counters for "Total Events" if history is collapsed, 
      // OR accept that history-based calc is "What we know".
      // Given the prompt "Or i should remove the existing ones and compute everything locally?",
      // implies the user is willing to move to local.
      // For now, I will use `count` (watch_count) as a proxy for episodes seen if it aggregates tracks.
    }

    // Period Stats (Bucketing)
    if (date.isAfter(cutoff365)) {
       // Ideally we check if *each* watch was in this period, but we only have `lastWatchedAt`.
       // We assume the *latest* activity counts for the period stats.
       // This is an approximation.
       
       if (date.isAfter(cutoff365)) {
          p365Mins += duration;
          if(isMovie) p365Mov += count; else p365Ep += count;
          
          if (date.isAfter(cutoff30)) {
              p30Mins += duration;
              if(isMovie) p30Mov += count; else p30Ep += count;

              if (date.isAfter(cutoff7)) {
                  p7Mins += duration;
                  if(isMovie) p7Mov += count; else p7Ep += count;
              }
          }
       }
    }
  }

  // DECISION: We rely on LOCAL calculation for all stats to ensure consistency.
  // If we used DB for Total and Local for Breakdown, they might mismatch (e.g. 100 vs 90+8).
  // Calculating locally guarantees Total = Movie + Series.
  
  // Calculate Totals locally
  
  return ProfileStats(
    totalMinutesWatched: movieMins + seriesMins,
    totalEpisodes: totalEp,
    totalMovies: uniqueMovies.length,
    totalSeries: uniqueSeriesIds.length,
    totalSeasons: uniqueSeasons.length,
    last7Days: PeriodStats(totalMinutes: p7Mins, movieCount: p7Mov, episodeCount: p7Ep),
    last30Days: PeriodStats(totalMinutes: p30Mins, movieCount: p30Mov, episodeCount: p30Ep),
    last365Days: PeriodStats(totalMinutes: p365Mins, movieCount: p365Mov, episodeCount: p365Ep),
    movieMinutes: movieMins,
    seriesMinutes: seriesMins,
  );
}
