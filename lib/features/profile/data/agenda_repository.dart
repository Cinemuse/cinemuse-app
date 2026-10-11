import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/error/supabase_extensions.dart';
import 'package:cinemuse_app/core/error/supabase_failure.dart';

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

    // Only fetch movies that are upcoming or released within the last 30 days
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final cutoffStr =
        "${cutoff.year.toString().padLeft(4, '0')}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}";

    // Chunk queries to avoid URL length issues or limits
    final allIds = followedIds.toList();
    final allRows = <Map<String, dynamic>>[];

    for (var i = 0; i < allIds.length; i += 100) {
      final chunk = allIds.sublist(
        i,
        i + 100 > allIds.length ? allIds.length : i + 100,
      );
      final cacheRes = await _supabase
          .from('upcoming_agenda_cache')
          .select()
          .eq('media_type', 'movie')
          .gte('release_date', cutoffStr)
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
  /// Read-only: completed series with a new aired episode are returned in
  /// `toReopen`, and the caller puts them back with [reopenSeries].
  Future<
    ({
      List<AgendaEvent> events,
      List<({int tmdbId, int season, int episode})> toReopen,
    })
  >
  fetchUpcomingEpisodes(String userId, Set<int> followedIds) async {
    final events = <AgendaEvent>[];
    final toReopen = <({int tmdbId, int season, int episode})>[];
    if (followedIds.isEmpty) return (events: events, toReopen: toReopen);

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
      final chunk = allIds.sublist(
        i,
        i + 100 > allIds.length ? allIds.length : i + 100,
      );
      final cacheRes = await _supabase
          .from('upcoming_agenda_cache')
          .select()
          .eq('media_type', 'tv')
          .inFilter('tmdb_id', chunk)
          .withErrorHandling();
      allRows.addAll(List<Map<String, dynamic>>.from(cacheRes as List));
    }

    final now = DateTime.now();
    final todayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    for (final row in allRows) {
      final seriesId = row['tmdb_id'] as int;
      final eventData = row['event_data'] as Map<String, dynamic>;

      final episodes = eventData['episodes'] as List? ?? [eventData];

      final startDate = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 30));

      for (final ep in episodes) {
        final airDateStr = ep['air_date'] as String?;
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
            if (airDate.isAfter(
              startDate.subtract(const Duration(seconds: 1)),
            )) {
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

      final historyItem = historyMap[seriesId];
      if (historyItem != null && historyItem['status'] == 'completed') {
        final next = firstAiredEpisodeAfter(
          season: historyItem['season'] as int? ?? 0,
          episode: historyItem['episode'] as int? ?? 0,
          episodes: episodes,
          todayStr: todayStr,
        );
        if (next != null) {
          toReopen.add((
            tmdbId: seriesId,
            season: next.season,
            episode: next.episode,
          ));
        }
      }
    }

    return (events: events, toReopen: toReopen);
  }

  /// Puts a completed series back in Continue Watching at [season] /
  /// [episode]. Only a row that is still "completed" changes, so a second
  /// call or a show the user started meanwhile is left alone.
  /// Throws an [AppFailure].
  Future<void> reopenSeries({
    required String userId,
    required int tmdbId,
    required int season,
    required int episode,
  }) async {
    final rows = await _supabase
        .from('watch_history')
        .update({
          'season': season,
          'episode': episode,
          'status': 'watching',
          'progress_seconds': 0,
          'total_duration': 0,
          'last_watched_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('tmdb_id', tmdbId)
        .eq('media_type', 'tv')
        .eq('status', 'completed')
        .select('tmdb_id')
        .withAppFailure();
    if ((rows as List).isNotEmpty) {
      await _watchHistoryRepo.syncWatchHistory(userId);
    }
  }
}

/// The first episode in [episodes] (one season from the agenda cache) that
/// aired on or before [todayStr] and comes after [season] / [episode].
/// Only the next episode of the same season or episode 1 of the next season
/// count: anything further would skip episodes the cache doesn't list.
({int season, int episode})? firstAiredEpisodeAfter({
  required int season,
  required int episode,
  required List<dynamic> episodes,
  required String todayStr,
}) {
  ({int season, int episode})? first;
  for (final ep in episodes) {
    final airDateStr = ep['air_date'] as String?;
    if (airDateStr == null ||
        airDateStr.isEmpty ||
        airDateStr.compareTo(todayStr) > 0) {
      continue;
    }
    final s = ep['season_number'] as int? ?? 0;
    final e = ep['episode_number'] as int? ?? 0;
    final isAfter = s > season || (s == season && e > episode);
    final isBeforeFirst =
        first == null ||
        s < first.season ||
        (s == first.season && e < first.episode);
    if (isAfter && isBeforeFirst) first = (season: s, episode: e);
  }
  if (first == null) return null;
  final isNext =
      (first.season == season && first.episode == episode + 1) ||
      (first.season == season + 1 && first.episode == 1);
  return isNext ? first : null;
}
