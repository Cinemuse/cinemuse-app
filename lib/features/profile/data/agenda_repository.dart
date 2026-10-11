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

  /// Collects all TMDB IDs the user "follows" (watched, watchlist,
  /// favorites, custom lists), plus each show's watch history row, which
  /// [fetchUpcomingEpisodes] needs (one history query per reload).
  Future<
    ({
      Set<int> movieIds,
      Set<int> seriesIds,
      Map<int, Map<String, dynamic>> seriesHistory,
    })
  >
  getFollowedIds(String userId) async {
    final movieIds = <int>{};
    final seriesIds = <int>{};
    final seriesHistory = <int, Map<String, dynamic>>{};

    void follow(dynamic row) {
      final id = row['tmdb_id'] as int;
      switch (MediaItem.fromString(row['media_type'])) {
        case MediaKind.movie:
          movieIds.add(id);
        case MediaKind.tv:
          seriesIds.add(id);
        case MediaKind.episode:
          break;
      }
    }

    // 1. From Watch History
    final historyRes = await _supabase
        .from('watch_history')
        .select('tmdb_id, media_type, season, episode, status')
        .eq('user_id', userId)
        .withErrorHandling();

    for (final row in (historyRes as List)) {
      follow(row);
      if (MediaItem.fromString(row['media_type']) == MediaKind.tv) {
        seriesHistory[row['tmdb_id'] as int] = row as Map<String, dynamic>;
      }
    }

    // 2. From Lists (Watchlist, Favorites, Custom)
    final listsRes = await _supabase
        .from('lists')
        .select('list_items(tmdb_id, media_type)')
        .eq('user_id', userId)
        .withErrorHandling();

    for (final list in (listsRes as List)) {
      (list['list_items'] as List).forEach(follow);
    }

    return (
      movieIds: movieIds,
      seriesIds: seriesIds,
      seriesHistory: seriesHistory,
    );
  }

  /// Rows of `upcoming_agenda_cache` for [ids], 100 IDs per query to keep
  /// the URL short. With [releasedFrom], only rows released on or after it.
  Future<List<Map<String, dynamic>>> _fetchCacheRows(
    String mediaType,
    Set<int> ids, {
    String? releasedFrom,
  }) async {
    final allIds = ids.toList();
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < allIds.length; i += 100) {
      final chunk = allIds.sublist(
        i,
        i + 100 > allIds.length ? allIds.length : i + 100,
      );
      var query = _supabase
          .from('upcoming_agenda_cache')
          .select()
          .eq('media_type', mediaType);
      if (releasedFrom != null) {
        query = query.gte('release_date', releasedFrom);
      }
      final res = await query.inFilter('tmdb_id', chunk).withErrorHandling();
      rows.addAll(List<Map<String, dynamic>>.from(res as List));
    }
    return rows;
  }

  /// Fetches upcoming movies from the cache table
  Future<List<AgendaEvent>> fetchUpcomingMovies(Set<int> followedIds) async {
    if (followedIds.isEmpty) return [];

    // Only movies that are upcoming or released within the last 30 days
    final now = DateTime.now();
    final rows = await _fetchCacheRows(
      'movie',
      followedIds,
      releasedFrom: dateOnly(DateTime(now.year, now.month, now.day - 30)),
    );
    return [
      for (final row in rows)
        AgendaEvent.fromMovie(row['event_data'] as Map<String, dynamic>),
    ];
  }

  /// Fetches upcoming episodes for followed series from the cache table.
  /// Read-only: completed series in [seriesHistory] with a new aired episode
  /// are returned in `toReopen`, and the caller puts them back with
  /// [reopenSeries].
  Future<
    ({
      List<AgendaEvent> events,
      List<({int tmdbId, int season, int episode})> toReopen,
    })
  >
  fetchUpcomingEpisodes(
    Set<int> followedIds,
    Map<int, Map<String, dynamic>> seriesHistory,
  ) async {
    final events = <AgendaEvent>[];
    final toReopen = <({int tmdbId, int season, int episode})>[];
    if (followedIds.isEmpty) return (events: events, toReopen: toReopen);

    final rows = await _fetchCacheRows('tv', followedIds);

    final now = DateTime.now();
    final todayStr = dateOnly(now);
    final startDate = DateTime(now.year, now.month, now.day - 30);

    for (final row in rows) {
      final seriesId = row['tmdb_id'] as int;
      final eventData = row['event_data'] as Map<String, dynamic>;

      final episodes = eventData['episodes'] as List? ?? [eventData];

      for (final ep in episodes) {
        // Episodes without a valid date (TBD) are always shown.
        final airDate = DateTime.tryParse(ep['air_date'] as String? ?? '');
        if (airDate != null && airDate.isBefore(startDate)) continue;
        events.add(
          AgendaEvent.fromEpisode(
            seriesId: seriesId,
            seriesName: eventData['series_name'] ?? '',
            seriesPosterPath: eventData['series_poster_path'],
            epJson: ep,
          ),
        );
      }

      final historyItem = seriesHistory[seriesId];
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

/// [date] as `yyyy-MM-dd`, the format of the cache's date columns.
String dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
