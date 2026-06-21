import 'package:cinemuse_app/core/error/supabase_extensions.dart';

import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/profile/domain/agenda_event.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AgendaRepository {
  final SupabaseClient _supabase;
  final WatchHistoryRepository _watchHistoryRepo;

  AgendaRepository(this._supabase, this._watchHistoryRepo);

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
      if (type == MediaKind.movie) {
        movieIds.add(id);
      } else if (type == MediaKind.tv) {
        seriesIds.add(id);
      }
    }

    // 2. From Lists (Watchlist, Favorites, Custom)
    final listsRes = await _supabase
        .from('lists')
        .select('list_items(tmdb_id, media_type)')
        .eq('user_id', userId)
        .withErrorHandling();

    for (final list in (listsRes as List)) {
      final items = list['list_items'] as List;
      for (final item in items) {
        final type = MediaItem.fromString(item['media_type']);
        final id = item['tmdb_id'] as int;
        if (type == MediaKind.movie) {
          movieIds.add(id);
        } else if (type == MediaKind.tv) {
          seriesIds.add(id);
        }
      }
    }

    return {MediaKind.movie: movieIds, MediaKind.tv: seriesIds};
  }

  /// Fetches upcoming movies from the cache table
  Future<List<AgendaEvent>> fetchUpcomingMovies(Set<int> followedIds) async {
    if (followedIds.isEmpty) return [];

    final events = <AgendaEvent>[];
    
    // Chunk queries to avoid URL length issues or limits
    final allIds = followedIds.toList();
    final allRows = <Map<String, dynamic>>[];
    
    for (var i = 0; i < allIds.length; i += 100) {
      final chunk = allIds.sublist(i, i + 100 > allIds.length ? allIds.length : i + 100);
      final cacheRes = await _supabase
          .from('upcoming_agenda_cache')
          .select()
          .eq('media_type', 'movie')
          .inFilter('tmdb_id', chunk)
          .withErrorHandling();
      allRows.addAll(List<Map<String, dynamic>>.from(cacheRes as List));
    }

    for (final row in allRows) {
      final eventData = row['event_data'] as Map<String, dynamic>;
      events.add(AgendaEvent.fromMovie(eventData));
    }

    return events;
  }

  /// Fetches upcoming episodes for followed series from the cache table.
  /// Also syncs new episodes back to "Continue Watching" if they are out.
  Future<List<AgendaEvent>> fetchUpcomingEpisodes(
    String userId,
    Set<int> followedIds,
  ) async {
    if (followedIds.isEmpty) return [];

    final events = <AgendaEvent>[];

    // Get current watch history to check for "caught up" status
    final historyRes = await _supabase
        .from('watch_history')
        .select('tmdb_id, season, episode, status')
        .eq('user_id', userId)
        .eq('media_type', 'tv')
        .order('last_watched_at', ascending: false)
        .withErrorHandling();

    final historyMap = <int, Map<String, dynamic>>{};
    for (final row in (historyRes as List)) {
      final id = row['tmdb_id'] as int;
      if (!historyMap.containsKey(id)) {
        historyMap[id] = row;
      }
    }

    // Fetch from denormalized cache table
    final allIds = followedIds.toList();
    final allRows = <Map<String, dynamic>>[];
    
    for (var i = 0; i < allIds.length; i += 100) {
      final chunk = allIds.sublist(i, i + 100 > allIds.length ? allIds.length : i + 100);
      final cacheRes = await _supabase
          .from('upcoming_agenda_cache')
          .select()
          .eq('media_type', 'tv')
          .inFilter('tmdb_id', chunk)
          .withErrorHandling();
      allRows.addAll(List<Map<String, dynamic>>.from(cacheRes as List));
    }

    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    for (final row in allRows) {
      final seriesId = row['tmdb_id'] as int;
      final eventData = row['event_data'] as Map<String, dynamic>;
      
      final episodes = eventData['episodes'] as List? ?? [eventData];

      final startDate = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 30));

      Map<String, dynamic>? verifiedLastAired;

      for (final ep in episodes) {
        final airDateStr = ep['air_date'] as String?;
        if (airDateStr != null && airDateStr.isNotEmpty && airDateStr.compareTo(todayStr) <= 0) {
          verifiedLastAired = ep;
        }

        if (airDateStr == null || airDateStr.isEmpty) {
          events.add(
            AgendaEvent.fromEpisode(
              seriesId: seriesId,
              seriesName: eventData['series_name'] ?? '',
              seriesPosterPath: eventData['series_poster_path'],
              epJson: ep,
            ),
          );
        } else {
          try {
            final airDate = DateTime.parse(airDateStr);
            if (airDate.isAfter(startDate.subtract(const Duration(seconds: 1)))) {
              events.add(
                AgendaEvent.fromEpisode(
                  seriesId: seriesId,
                  seriesName: eventData['series_name'] ?? '',
                  seriesPosterPath: eventData['series_poster_path'],
                  epJson: ep,
                ),
              );
            }
          } catch (_) {
            events.add(
              AgendaEvent.fromEpisode(
                seriesId: seriesId,
                seriesName: eventData['series_name'] ?? '',
                seriesPosterPath: eventData['series_poster_path'],
                epJson: ep,
              ),
            );
          }
        }
      }

      // SYNC LOGIC: Check if this series should be added back to "watching"
      final historyItem = historyMap[seriesId];
      if (historyItem != null && historyItem['status'] == 'completed') {
        if (verifiedLastAired != null) {
          final sHistory = historyItem['season'] as int? ?? 0;
          final eHistory = historyItem['episode'] as int? ?? 0;
          final lastS = verifiedLastAired['season_number'] as int? ?? 0;
          final lastE = verifiedLastAired['episode_number'] as int? ?? 0;
          
          if (lastS > sHistory || (lastS == sHistory && lastE > eHistory)) {
             // We can safely update watch_history here
             final watchingEntry = {
                'user_id': userId,
                'tmdb_id': seriesId,
                'media_type': 'tv',
                'season': lastS,
                'episode': lastE,
                'status': 'watching',
                'progress_seconds': 0,
                'total_duration': 0,
                'last_watched_at': DateTime.now().toUtc().toIso8601String(),
             };
             
             // Fire and forget the update
             _supabase.from('watch_history').upsert(watchingEntry).then((_) {
                _watchHistoryRepo.syncWatchHistory(userId);
             });
          }
        }
      }
    }

    return events;
  }
}
