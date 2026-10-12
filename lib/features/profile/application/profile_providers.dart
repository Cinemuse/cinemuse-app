import 'dart:async';

import 'dart:convert';
import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/core/error/supabase_failure.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/profile/domain/profile.dart';
import 'package:cinemuse_app/features/profile/domain/profile_stats.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';

// 1. Current User ID Provider
final userIdProvider = Provider<String?>((ref) {
  final user = ref.watch(authProvider).valueOrNull;
  return user?.id;
});

// 2. Profile Stream Provider (Resilient with Cache Fallback)
final profileStreamProvider = StreamProvider<Profile?>((ref) async* {
  final userId = ref.watch(userIdProvider);
  if (userId == null) {
    yield null;
    return;
  }

  final db = ref.watch(appDatabaseProvider);
  var hasYielded = false;

  // 1. Instant Cache Fallback
  try {
    final cached = await db.getCachedProfile(userId);
    if (cached != null) {
      hasYielded = true;
      yield Profile(
        id: cached.id,
        username: cached.username,
        avatarUrl: cached.avatarUrl,
        preferences: cached.preferences != null
            ? jsonDecode(cached.preferences!) as Map<String, dynamic>
            : {},
        createdAt: cached.createdAt,
        updatedAt: cached.updatedAt,
      );
    }
  } catch (e, s) {
    // The remote stream below still delivers the profile.
    AppLogger.warn(
      'profileStreamProvider',
      'Could not read the cached profile',
      error: e,
      stackTrace: s,
    );
  }

  // 2. Real-time background update
  try {
    final stream = ref
        .read(supabaseClientProvider)
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((event) {
          if (event.isEmpty) return null;
          return Profile.fromJson(event.first);
        });

    await for (final profile in stream) {
      // Sync remote update to local cache background
      if (profile != null) {
        // Local cache only: the stream must keep yielding remote profiles.
        unawaited(
          db
              .upsertProfile(
                CachedProfilesCompanion(
                  id: Value(profile.id),
                  username: Value(profile.username),
                  avatarUrl: Value(profile.avatarUrl),
                  preferences: Value(jsonEncode(profile.preferences)),
                  createdAt: Value(profile.createdAt),
                  updatedAt: Value(profile.updatedAt),
                ),
              )
              .catchError(
                (Object e, StackTrace s) => AppLogger.warn(
                  'profileStreamProvider',
                  'Could not cache the profile locally',
                  error: e,
                  stackTrace: s,
                ),
              ),
        );
      }
      hasYielded = true;
      yield profile;
    }
  } catch (e, s) {
    AppLogger.warn(
      'profileStreamProvider',
      'Profile realtime stream failed; live updates stop',
      error: e,
      stackTrace: s,
    );
    // With a profile already shown, keep it; with none, show the error
    // instead of loading forever (REV-90).
    if (!hasYielded) rethrow;
  }
});

// 3. Watch History Stream Provider (All history for stats)
final watchHistoryStreamProvider = StreamProvider<List<WatchHistory>>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return Stream.value([]);

  return ref
      .watch(watchHistoryRepositoryProvider)
      .watchHistory(userId)
      .handleError((error, stackTrace) {
        // On expired JWT or channel errors, return empty list.
        // The session refresh will eventually trigger a rebuild via authProvider.
        if (error is RealtimeSubscribeException) {
          return <WatchHistory>[];
        }
        throw error;
      });
});

// 3b. Watch Logs Provider (Full chronological event history from watch_logs for timeline)
final watchLogsProvider = FutureProvider<List<WatchHistory>>((ref) async {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return [];

  // Invalidate / re-fetch whenever local watch history updates
  ref.watch(watchHistoryStreamProvider);

  return ref
      .watch(watchHistoryRepositoryProvider)
      .getAllWatchLogs(userId, forceRefresh: true);
});

// 4. Recently Watched Stream Provider (Log-based, permanent history)
final recentlyWatchedStreamProvider = Provider<AsyncValue<List<WatchHistory>>>((
  ref,
) {
  final historyAsync = ref.watch(watchHistoryStreamProvider);
  return historyAsync.whenData((list) => list.take(20).toList());
});

// 5. Computed Stats Provider (Fetching from Supabase View)
final profileStatsProvider = StreamProvider<ProfileStats>((ref) async* {
  final userId = ref.watch(userIdProvider);
  if (userId == null) {
    yield ProfileStats.empty();
    return;
  }

  // Local database stream acts as an invalidator trigger
  // Every time a user watches something, the local watch_histories table is merged/updated,
  // triggering this stream, which in turn fetches the true aggregated stats from backend.
  ref.watch(watchHistoryStreamProvider);

  // Errors reach the UI as AsyncError; Riverpod keeps the last stats as
  // its value, so a failed refresh never shows zeros as if real (REV-90).
  final res = await ref
      .read(supabaseClientProvider)
      .from('user_stats')
      .select()
      .eq('user_id', userId)
      .maybeSingle()
      .withAppFailure();
  if (res == null) {
    yield ProfileStats.empty();
    return;
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
});
