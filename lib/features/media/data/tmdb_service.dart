import 'dart:async';

import 'package:cinemuse_app/core/data/api_keys_repository.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:cinemuse_app/core/application/locale_service.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/media/domain/episode_item.dart';
import 'package:cinemuse_app/features/media/domain/media_details_parts.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/person.dart';
import 'package:cinemuse_app/features/media/domain/search_result.dart';
import 'package:cinemuse_app/features/media/domain/watch_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final tmdbServiceProvider = Provider<TmdbService>((ref) {
  final locale = ref.watch(localeProvider);
  final language = locale.languageCode == 'it' ? 'it-IT' : 'en-US';
  return TmdbService(
    ref.read(dioProvider),
    language,
    () => ref.read(tmdbApiKeyProvider.future),
  );
});

/// Talks to the TMDB API.
///
/// Lists (search, Explore, popular, trending) throw an [AppFailure] when TMDB
/// can't answer. The single-item lookups still return `null` on any error
/// (see `_getOrNull`).
class TmdbService {
  static const _tag = 'TmdbService';

  final Dio _dio;
  final String _language;
  final String _baseUrl = 'https://api.themoviedb.org/3';

  final TmdbKeyLoader _apiKey;

  TmdbService(this._dio, this._language, this._apiKey);

  /// GETs [path] and returns the decoded body. Any Dio error becomes an
  /// [AppFailure] whose message names the path but never the API key. With
  /// no key (none on the server, none saved), the key's failure is thrown.
  Future<dynamic> _get(String path, [Map<String, dynamic>? query]) async {
    final apiKey = await _apiKey();
    try {
      final res = await _dio.get(
        '$_baseUrl$path',
        queryParameters: {'api_key': apiKey, ...?query},
      );
      return res.data;
    } on DioException catch (e, st) {
      throw _failureFrom(e, st, path);
    }
  }

  static AppFailure _failureFrom(DioException e, StackTrace st, String path) {
    final status = e.response?.statusCode;
    final message = 'TMDB GET $path failed (${e.type.name}, status $status)';
    return switch (e.type) {
      DioExceptionType.badResponse when status == 404 => NotFoundFailure(
        message,
        cause: e,
        stackTrace: st,
      ),
      DioExceptionType.badResponse => ServerFailure(
        message,
        statusCode: status,
        cause: e,
        stackTrace: st,
      ),
      DioExceptionType.cancel => UnknownFailure(
        message,
        cause: e,
        stackTrace: st,
      ),
      _ => NetworkFailure(message, cause: e, stackTrace: st),
    };
  }

  /// Like [_get], but returns `null` on any failure, after logging it.
  // TODO(REV-30): callers still read null as "not found", so offline looks
  // like a missing title. Throw instead once they handle errors: Continue
  // Watching (REV-68), watch history (8j), player progress (8m).
  Future<dynamic> _getOrNull(String path, [Map<String, dynamic>? query]) async {
    try {
      return await _get(path, query);
    } on NotFoundFailure {
      return null;
    } on AppFailure catch (e) {
      AppLogger.warn(_tag, '${e.message}, returning null');
      return null;
    }
  }

  static const int _maxCachedEntries = 50;
  static const Duration _cacheTtl = Duration(minutes: 15);
  final Map<String, _CachedMediaDetails> _detailsCache = {};
  final Map<String, Future<MediaItem?>> _inflightRequests = {};

  /// Clears in-memory details cache.
  void clearCache() {
    _detailsCache.clear();
    _inflightRequests.clear();
  }

  /// A title's full details (cast, videos, seasons…), by its TMDB id or its
  /// IMDb number (`tt…`); [type] is `movie`, or `tv` / `series`.
  Future<MediaItem?> getMediaDetails(String id, String type) async {
    final cacheKey = '$type:$id:$_language';

    final cached = _detailsCache[cacheKey];
    if (cached != null) {
      if (DateTime.now().difference(cached.timestamp) < _cacheTtl) {
        return cached.item;
      }
      _detailsCache.remove(cacheKey);
    }

    final inflight = _inflightRequests[cacheKey];
    if (inflight != null) {
      return inflight;
    }

    final future = _fetchMediaDetailsFromNetwork(id, type, cacheKey);
    _inflightRequests[cacheKey] = future;
    return future;
  }

  Future<MediaItem?> _fetchMediaDetailsFromNetwork(
    String id,
    String type,
    String cacheKey,
  ) async {
    try {
      // Normalize type (tmdb uses 'tv' for series)
      final normalizedType = (type == 'series' || type == 'tv')
          ? 'tv'
          : 'movie';

      // Handle IMDB ID conversion if needed
      String tmdbId = id;
      if (id.startsWith('tt')) {
        final data = await _getOrNull('/find/$id', {
          'external_source': 'imdb_id',
        });
        if (data == null) return null;
        if (normalizedType == 'movie' && data['movie_results'].isNotEmpty) {
          tmdbId = data['movie_results'][0]['id'].toString();
        } else if (normalizedType == 'tv' && data['tv_results'].isNotEmpty) {
          tmdbId = data['tv_results'][0]['id'].toString();
        } else {
          return null;
        }
      }

      final data = await _getOrNull('/$normalizedType/$tmdbId', {
        'language': _language,
        'append_to_response':
            'credits,videos,similar,recommendations,external_ids,translations,reviews,images'
            '${normalizedType == 'tv' ? ',${MediaItem.firstEpisodeResponse}' : ''}',
        'include_image_language': 'en,it,null',
        // A title's videos in both languages, mixed by date: the videos row
        // puts the app's language first.
        'include_video_language': 'it,en',
      });
      if (data != null && data is Map<String, dynamic>) {
        final item = MediaItem.fromTmdbDetails(
          data,
          MediaItem.fromString(type),
        );
        if (_detailsCache.length >= _maxCachedEntries) {
          _detailsCache.remove(_detailsCache.keys.first);
        }
        _detailsCache[cacheKey] = _CachedMediaDetails(item, DateTime.now());
        return item;
      }
      return null;
    } finally {
      // remove() hands back the stored in-flight Future (this very request):
      // we only drop it from the map; awaiting it would wait on itself.
      unawaited(_inflightRequests.remove(cacheKey));
    }
  }

  /// A season's episodes; null when TMDB has no such season.
  Future<List<EpisodeItem>?> getSeasonEpisodes(
    int tmdbId,
    int seasonNumber,
  ) async {
    final data = await _getOrNull('/tv/$tmdbId/season/$seasonNumber', {
      'language': _language,
    });
    if (data is! Map<String, dynamic>) return null;
    return EpisodeItem.listFromTmdbSeason(data, seasonNumber);
  }

  /// A film collection (a saga) with its films.
  Future<MediaCollection?> getCollectionDetails(int collectionId) async {
    final data = await _getOrNull('/collection/$collectionId', {
      'language': _language,
    });
    if (data is! Map<String, dynamic>) return null;
    return MediaCollection.fromTmdbMap(data);
  }

  Future<String?> getImdbId(int tmdbId, String type) async {
    final endpoint = type == 'movie' ? 'movie' : 'tv';
    final data = await _getOrNull('/$endpoint/$tmdbId/external_ids');
    return data?['imdb_id'] as String?;
  }

  Future<String?> getEpisodeImdbId(
    int showId,
    int seasonNumber,
    int episodeNumber,
  ) async {
    final data = await _getOrNull(
      '/tv/$showId/season/$seasonNumber/episode/$episodeNumber/external_ids',
    );
    return data?['imdb_id'] as String?;
  }

  // Trending & Popular
  Future<List<MediaItem>> getTrending() async {
    final data = await _get('/trending/all/week', {'language': _language});
    final results = List<Map<String, dynamic>>.from(data['results']);
    return results
        .where((item) => item['media_type'] != 'person')
        .map(MediaItem.fromTmdbMap)
        .toList();
  }

  Future<List<MediaItem>> getPopularMovies() async {
    final data = await _get('/movie/popular', {'language': _language});
    final results = List<Map<String, dynamic>>.from(data['results']);
    return results
        .map((item) => MediaItem.fromTmdbMap({...item, 'media_type': 'movie'}))
        .toList();
  }

  Future<List<MediaItem>> getPopularSeries() async {
    final data = await _get('/tv/popular', {'language': _language});
    final results = List<Map<String, dynamic>>.from(data['results']);
    return results
        .map((item) => MediaItem.fromTmdbMap({...item, 'media_type': 'tv'}))
        .toList();
  }

  /// One page of movies, shows and people matching [query].
  Future<TmdbPage<SearchResult>> searchMulti(
    String query, {
    int page = 1,
  }) async {
    if (query.isEmpty) {
      return (results: <SearchResult>[], totalPages: 0);
    }
    final data = await _get('/search/multi', {
      'language': _language,
      'query': query,
      'include_adult': false,
      'page': page,
    });
    return _page(data, page, SearchResult.fromTmdbMap);
  }

  /// TMDB's [data] for list page [page], each result read by [read].
  static TmdbPage<T> _page<T>(
    dynamic data,
    int page,
    T Function(Map<String, dynamic>) read,
  ) => (
    results: List<Map<String, dynamic>>.from(
      data['results'],
    ).map(read).toList(),
    totalPages: (data['total_pages'] as num?)?.toInt() ?? page,
  );

  /// One page of [type]'s titles (movie or tv) that match the filters.
  Future<TmdbPage<MediaItem>> discover({
    required String type,
    required int page,
    String? sortBy,
    List<int>? genres,
    List<String>? languages,
    double? minRating,
    double? maxRating,
    int? minYear,
    int? maxYear,
    int? minVotes,
    int? maxVotes,
    int? minRuntime,
    int? maxRuntime,
    List<int>? watchProviders,
    String? watchRegion,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'language': _language,
      'include_adult': false,
      'sort_by': sortBy ?? 'popularity.desc',
    };

    if (genres != null && genres.isNotEmpty) {
      queryParams['with_genres'] = genres.join(',');
    }
    if (languages != null && languages.isNotEmpty) {
      queryParams['with_original_language'] = languages.join('|');
    }
    if (minRating != null) queryParams['vote_average.gte'] = minRating;
    if (maxRating != null) queryParams['vote_average.lte'] = maxRating;
    if (minVotes != null) queryParams['vote_count.gte'] = minVotes;
    if (maxVotes != null) queryParams['vote_count.lte'] = maxVotes;
    if (minRuntime != null) queryParams['with_runtime.gte'] = minRuntime;
    if (maxRuntime != null) queryParams['with_runtime.lte'] = maxRuntime;

    if (watchProviders != null && watchProviders.isNotEmpty) {
      queryParams['with_watch_providers'] = watchProviders.join('|');
      if (watchRegion != null) queryParams['watch_region'] = watchRegion;
    }

    final dateField = type == 'movie'
        ? 'primary_release_date'
        : 'first_air_date';
    if (minYear != null) queryParams['$dateField.gte'] = '$minYear-01-01';
    if (maxYear != null) queryParams['$dateField.lte'] = '$maxYear-12-31';

    final data = await _get('/discover/$type', queryParams);
    // Discover's results don't say their kind: it is the one asked for.
    return _page(
      data,
      page,
      (item) => MediaItem.fromTmdbMap({...item, 'media_type': type}),
    );
  }

  /// A person with their films and series.
  Future<PersonDetails?> getPersonDetails(int id) async {
    final data = await _getOrNull('/person/$id', {
      'language': _language,
      'append_to_response': 'combined_credits,external_ids,images',
    });
    if (data is! Map<String, dynamic>) return null;
    return PersonDetails.fromTmdbMap(data);
  }

  Future<TmdbPage<PersonSummary>> getPopularPersons(int page) async {
    final data = await _get('/person/popular', {
      'page': page,
      'language': _language,
    });
    return _page(data, page, PersonSummary.fromTmdbMap);
  }

  /// The streaming services TMDB knows in [region], for movies or series.
  Future<List<WatchProvider>> getWatchProviders(
    String type,
    String region,
  ) async {
    final data = await _get(
      '/watch/providers/${type == 'tv' ? 'tv' : 'movie'}',
      {'watch_region': region, 'language': _language},
    );
    return [
      for (final p in List<Map<String, dynamic>>.from(data['results']))
        WatchProvider.fromTmdbMap(p, region),
    ];
  }

  /// The countries TMDB has streaming data for, named in the app's language.
  Future<List<WatchRegion>> getWatchRegions() async {
    final data = await _get('/watch/providers/regions', {
      'language': _language,
    });
    return [
      for (final r in List<Map<String, dynamic>>.from(data['results']))
        ?watchRegionFromTmdbMap(r),
    ];
  }
}

class _CachedMediaDetails {
  final MediaItem item;
  final DateTime timestamp;

  _CachedMediaDetails(this.item, this.timestamp);
}
