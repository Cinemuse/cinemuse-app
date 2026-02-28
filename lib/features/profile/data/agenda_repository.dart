import 'package:cinemuse_app/core/error/supabase_extensions.dart';
import 'package:cinemuse_app/core/services/tmdb_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/profile/domain/agenda_event.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AgendaRepository {
  final SupabaseClient _supabase;
  final TmdbService _tmdb;
  final WatchHistoryRepository _watchHistoryRepo;

  AgendaRepository(this._supabase, this._tmdb, this._watchHistoryRepo);

  /// Collects all TMDB IDs the user "follows" (watched, watchlist, favorites, custom lists).
  Future<Map<MediaKind, Set<int>>> getFollowedIds(String userId) async {
    final movieIds = <int>{};
    final seriesIds = <int>{};

    // 1. From Watch History
    final historyRes = await _supabase
        .from('watch_history')
        .select('tmdb_id, media_type')
        .eq('user_id', userId)
        .withErrorHandling();
    
    for (final row in (historyRes as List)) {
      final type = MediaItem.fromString(row['media_type']);
      final id = row['tmdb_id'] as int;
      if (type == MediaKind.movie) movieIds.add(id);
      else if (type == MediaKind.tv) seriesIds.add(id);
    }

    // 2. From Lists (Watchlist, Favorites, Custom)
    final listsRes = await _supabase
        .from('lists')
        .select('list_items(media_tmdb_id, media_type)')
        .eq('user_id', userId)
        .withErrorHandling();

    for (final list in (listsRes as List)) {
      final items = list['list_items'] as List;
      for (final item in items) {
        final type = MediaItem.fromString(item['media_type']);
        final id = item['media_tmdb_id'] as int;
        if (type == MediaKind.movie) movieIds.add(id);
        else if (type == MediaKind.tv) seriesIds.add(id);
      }
    }

    return {
      MediaKind.movie: movieIds,
      MediaKind.tv: seriesIds,
    };
  }

  /// Fetches upcoming movies from TMDB for specific followed IDs.
  Future<List<AgendaEvent>> fetchUpcomingMovies(Set<int> followedIds) async {
    if (followedIds.isEmpty) return [];

    final today = DateTime.now();
    final todayNoTime = DateTime(today.year, today.month, today.day);
    // Be more generous: show items from the last 30 days to the future (no upper limit)
    final startDate = todayNoTime.subtract(const Duration(days: 30));
    final events = <AgendaEvent>[];

    for (final movieId in followedIds) {
      final details = await _tmdb.getMediaDetails(movieId.toString(), 'movie');
      if (details == null) continue;

      final releaseStr = details['release_date'] ?? details['primary_release_date'];
      if (releaseStr == null || releaseStr.isEmpty) {
        // missing date = TBD
        events.add(AgendaEvent.fromMovie(details));
      } else {
        try {
          final releaseDate = DateTime.parse(releaseStr);
          if (releaseDate.isAfter(startDate.subtract(const Duration(seconds: 1)))) {
            events.add(AgendaEvent.fromMovie(details));
          }
        } catch (_) {
          // Invalid format (e.g. "2026") = TBD
          events.add(AgendaEvent.fromMovie(details));
        }
      }

      // Small delay for rate limiting
      await Future.delayed(const Duration(milliseconds: 30));
    }

    return events;
  }

  /// Fetches upcoming episodes for followed series.
  /// Also syncs new episodes back to "Continue Watching" if they are out.
  Future<List<AgendaEvent>> fetchUpcomingEpisodes(String userId, Set<int> followedIds) async {
    if (followedIds.isEmpty) return [];

    final today = DateTime.now();
    final todayNoTime = DateTime(today.year, today.month, today.day);
    final startDate = todayNoTime.subtract(const Duration(days: 30));
    final events = <AgendaEvent>[];

    // Get current watch history for all followed series to check for "caught up" status
    final historyRes = await _supabase
        .from('watch_history')
        .select('tmdb_id, season, episode, status')
        .eq('user_id', userId)
        .eq('media_type', 'tv')
        .withErrorHandling();
    
    final historyMap = <int, Map<String, dynamic>>{};
    for (final row in (historyRes as List)) {
      historyMap[row['tmdb_id'] as int] = row;
    }

    // To respect rate limits, we'll fetch details for each series sequentially with a small delay
    for (final seriesId in followedIds) {
      // 1. Check media_cache for status if possible (Optimization)
      final cacheRes = await _supabase
          .from('media_cache')
          .select('updated_at')
          .eq('tmdb_id', seriesId)
          .eq('media_type', 'tv')
          .maybeSingle();
      
      // If we wanted to be very aggressive we could cache 'Ended' status too, 
      // but let's stick to the web logic: fetch TV details.
      
      final details = await _tmdb.getMediaDetails(seriesId.toString(), 'tv');
      if (details == null) continue;

      final status = (details['status'] as String?)?.toLowerCase();
      if (status == 'ended' || status == 'canceled') continue;

      final nextEp = details['next_episode_to_air'];
      
      // SYNC LOGIC: Check if this series should be added back to "watching"
      final historyItem = historyMap[seriesId];
      final lastAired = details['last_episode_to_air'];

      if (lastAired != null) {
        final lastS = lastAired['season_number'] as int? ?? 0;
        final lastE = lastAired['episode_number'] as int? ?? 0;

        if (historyItem == null) {
          // Show is followed but no history? Maybe it's in watchlist.
          // In web we don't automatically add, but here we could.
          // Let's stick to "if they have history" to be safe.
        } else {
          final sHistory = historyItem['season'] as int? ?? 0;
          final eHistory = historyItem['episode'] as int? ?? 0;
          final status = historyItem['status'] as String? ?? '';

          // Only sync if the series is marked as 'completed' (meaning they were caught up)
          // or if they are in 'watching' but we've detected newer episodes than their current record.
          // Actually, if they are 'watching' S01E05, we don't want to jump them.
          // So let's stick to status == 'completed'.
          
          if (status == 'completed' && (lastS > sHistory || (lastS == sHistory && lastE > eHistory))) {
             // There is a newer aired episode than what's in history!
             // Add it back to Continue Watching row.
             await _watchHistoryRepo.upsertNextEpisode(
               userId: userId, 
               tmdbId: seriesId, 
               currentSeason: sHistory, 
               currentEpisode: eHistory, 
               seriesDetails: details,
             );
          }
        }
      }

      if (nextEp == null) continue;

      // Small delay for rate limiting
      await Future.delayed(const Duration(milliseconds: 50));

      final seasonNum = nextEp['season_number'] as int;
      final seasonDetails = await _tmdb.getSeasonDetails(seriesId, seasonNum);
      if (seasonDetails == null) continue;

      final episodes = seasonDetails['episodes'] as List? ?? [];
      for (final ep in episodes) {
        final airDateStr = ep['air_date'] as String?;
        if (airDateStr == null || airDateStr.isEmpty) {
          events.add(AgendaEvent.fromEpisode(
            seriesId: seriesId,
            seriesName: details['name'] ?? '',
            seriesPosterPath: details['poster_path'],
            epJson: ep,
          ));
        } else {
          try {
            final airDate = DateTime.parse(airDateStr);
            if (airDate.isAfter(startDate.subtract(const Duration(seconds: 1)))) {
              events.add(AgendaEvent.fromEpisode(
                seriesId: seriesId,
                seriesName: details['name'] ?? '',
                seriesPosterPath: details['poster_path'],
                epJson: ep,
              ));
            }
          } catch (_) {
            events.add(AgendaEvent.fromEpisode(
              seriesId: seriesId,
              seriesName: details['name'] ?? '',
              seriesPosterPath: details['poster_path'],
              epJson: ep,
            ));
          }
        }
      }
      
      // More delay between series
      await Future.delayed(const Duration(milliseconds: 50));
    }

    return events;
  }
}
