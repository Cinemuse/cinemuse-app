import 'dart:async';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/streaming/anime/anime_mapping_service.dart';
import 'package:cinemuse_app/features/streaming/debrid/addon_link_check_service.dart';
import 'package:cinemuse_app/features/streaming/debrid/composite_debrid_service.dart';
import 'package:cinemuse_app/features/streaming/models/provider_search_status.dart';
import 'package:cinemuse_app/features/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/features/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/features/streaming/models/stream_metadata.dart';
import 'package:cinemuse_app/features/streaming/models/stream_search_context.dart';
import 'package:cinemuse_app/features/streaming/ranking/stream_filter.dart';
import 'package:cinemuse_app/features/streaming/ranking/stream_ranker.dart';
import 'package:cinemuse_app/features/streaming/sources/base_source.dart';
import 'package:cinemuse_app/features/streaming/sources/stremio_source.dart';
import 'package:flutter/foundation.dart';

class UnifiedStreamResolver {
  final List<BaseSource> _sources;
  final TmdbService _tmdbService;
  final AnimeMappingService _animeMappingService;
  final MediaRepository _mediaRepository;
  final UserSettings _settings;
  final VideoResolution _maxResolution;
  final CompositeDebridService? _debridService;
  final AddonLinkCheckService? _linkCheck;

  final Map<String, _CachedSearch> _searchCache = {};
  static const Duration _cacheDuration = Duration(minutes: 30);
  static const String _logTag = 'UnifiedStreamResolver';

  static String _cacheKey(
    String queryId,
    String type,
    int? season,
    int? episode,
  ) => '$type:$queryId:${season ?? 0}:${episode ?? 0}';

  /// Clears the in-memory search cache.
  @visibleForTesting
  void clearCache() {
    _searchCache.clear();
  }

  /// Checks if a valid (non-expired) cache entry exists for the given item.
  bool hasCachedStream(
    String queryId,
    String type, {
    int? season,
    int? episode,
  }) {
    final cacheKey = _cacheKey(queryId, type, season, episode);
    final cached = _searchCache[cacheKey];
    if (cached == null) return false;

    final isExpired =
        DateTime.now().difference(cached.timestamp) >= _cacheDuration;
    if (isExpired) {
      _searchCache.remove(cacheKey);
      return false;
    }
    return true;
  }

  /// Removes the cache entry for the given item from the cache.
  void clearCachedStream(
    String queryId,
    String type, {
    int? season,
    int? episode,
  }) {
    final cacheKey = _cacheKey(queryId, type, season, episode);
    _searchCache.remove(cacheKey);
    AppLogger.debug(_logTag, 'Cleared cached results for $cacheKey');
  }

  @visibleForTesting
  List<BaseSource> get sources => _sources;

  @visibleForTesting
  UserSettings get settings => _settings;

  UnifiedStreamResolver({
    required List<BaseSource> sources,
    required TmdbService tmdbService,
    required AnimeMappingService animeMappingService,
    required MediaRepository mediaRepository,
    required UserSettings settings,
    required VideoResolution maxResolution,
    CompositeDebridService? debridService,
    AddonLinkCheckService? linkCheck,
  }) : _sources = sources,
       _tmdbService = tmdbService,
       _animeMappingService = animeMappingService,
       _mediaRepository = mediaRepository,
       _settings = settings,
       _maxResolution = maxResolution,
       _debridService = debridService,
       _linkCheck = linkCheck;

  Future<StreamSearchResult> searchStreams(
    String queryId, // Can be TMDB ID (digits) or IMDB ID (tt...)
    String type, {
    int? season,
    int? episode,
    void Function(List<ProviderSearchStatus>)? onStatusUpdate,
    Future<void>? skipTrigger,
    MediaItem? preloadedDetails,
  }) async {
    final cacheKey = _cacheKey(queryId, type, season, episode);
    final cached = _searchCache[cacheKey];

    Timer? statusTimer;
    final kind = MediaItem.fromString(type);

    // The cached path is inside the try too, so its errors reach callers as
    // StreamingExceptions like the main path's (STR-06).
    try {
      if (cached != null &&
          DateTime.now().difference(cached.timestamp) < _cacheDuration) {
        AppLogger.debug(_logTag, 'Returning cached results for $cacheKey');
        // Availability is checked again: ranking depends on the debrid cache.
        final rankedCandidates = await _finalizeResults(
          cached.candidates,
          context: cached.context,
        );
        return StreamSearchResult(
          candidates: rankedCandidates,
          isAnime: cached.context.isAnime,
        );
      }

      if (_sources.isEmpty) {
        throw const NoStreamsFailure(
          NoStreamsReason.noAddons,
          'No streaming add-ons are enabled',
        );
      }

      // 1. Resolve Media Details and IDs
      final item =
          preloadedDetails ?? await _tmdbService.getMediaDetails(queryId, type);
      if (item == null) {
        throw const NoStreamsFailure(
          NoStreamsReason.noDetails,
          'Could not get the title details for the search',
        );
      }

      // Cache write only: resolving streams must not wait for it, and a
      // failed write only means the title is fetched again next time.
      unawaited(
        _mediaRepository.saveMediaItem(item).catchError((Object e) {
          AppLogger.warn(_logTag, 'Could not cache $kind $queryId', error: e);
        }),
      );

      final tmdbId = int.tryParse(queryId) ?? item.tmdbId;
      String? imdbId = _nonEmpty(item.imdbId);

      // 2. Concurrently resolve missing IMDB ID and Anime mapping
      final imdbTask = imdbId == null
          ? _tmdbService.getImdbId(tmdbId, type).then(_nonEmpty)
          : Future<String?>.value(imdbId);

      final animeTask = _animeMappingService.lookUp(
        tmdbId: tmdbId,
        type: type,
        season: season,
        episode: episode,
      );

      imdbId = await imdbTask;
      final anime = await animeTask;
      // No IMDb id is no reason to stop: the built-in and anime sources don't
      // use it, and the add-ons are asked by the TMDB id instead.

      final isAnime = anime.isAnime;
      final prefSub = isAnime && _settings.splitAnimePreferences
          ? _settings.animeSubtitleLanguage
          : _settings.subtitleLanguage;
      final preferredLanguages = <String>{
        if (prefSub.isNotEmpty) prefSub.toLowerCase() else 'it',
      }.toList();

      final context = StreamSearchContext(
        tmdbId: tmdbId.toString(),
        imdbId: imdbId,
        type: type,
        season: season,
        episode: episode,
        title: item.tmdbTitle ?? '',
        mapping: anime.match,
        isAnime: isAnime,
        preferredLanguages: preferredLanguages,
      );

      final stopwatch = Stopwatch()..start();
      final searchStatuses = _sources
          .map((s) => ProviderSearchStatus(providerName: s.name))
          .toList();
      onStatusUpdate?.call(searchStatuses);

      statusTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        final elapsed = stopwatch.elapsed;
        for (int i = 0; i < searchStatuses.length; i++) {
          if (searchStatuses[i].status == ProviderStatus.searching) {
            searchStatuses[i] = searchStatuses[i].copyWith(
              timeElapsed: elapsed,
            );
          }
        }
        onStatusUpdate?.call(searchStatuses);
      });

      final taskResults = List.generate(
        _sources.length,
        (_) => <StreamCandidate>[],
      );
      final taskFutures = <Future<void>>[];

      for (int i = 0; i < _sources.length; i++) {
        final source = _sources[i];
        final task = () async {
          try {
            final searchFuture = source.search(context);
            final candidates = _settings.enableAutoSkipProviders
                ? await searchFuture.timeout(const Duration(seconds: 10))
                : await searchFuture;
            taskResults[i] = candidates;
            searchStatuses[i] = searchStatuses[i].copyWith(
              status: ProviderStatus.finished,
              resultsCount: candidates.length,
              timeElapsed: stopwatch.elapsed,
            );
            onStatusUpdate?.call(searchStatuses);
          } on TimeoutException {
            searchStatuses[i] = searchStatuses[i].copyWith(
              status: ProviderStatus.failed,
              errorMessage: 'Timeout after 10s',
              timeElapsed: stopwatch.elapsed,
            );
            onStatusUpdate?.call(searchStatuses);
          } catch (e) {
            // One source failing must not stop the others; the status row
            // shows it as failed.
            AppLogger.warn(_logTag, '${source.name} search failed', error: e);
            searchStatuses[i] = searchStatuses[i].copyWith(
              status: ProviderStatus.failed,
              errorMessage: e.toString(),
              timeElapsed: stopwatch.elapsed,
            );
            onStatusUpdate?.call(searchStatuses);
          }
        }();
        taskFutures.add(task);
      }

      if (skipTrigger != null) {
        await Future.any([Future.wait(taskFutures), skipTrigger]);
      } else {
        await Future.wait(taskFutures);
      }

      stopwatch.stop();
      statusTimer.cancel();

      // If skipped/bypassed, mark any outstanding 'searching' status as failed/skipped
      for (int i = 0; i < searchStatuses.length; i++) {
        if (searchStatuses[i].status == ProviderStatus.searching) {
          searchStatuses[i] = searchStatuses[i].copyWith(
            status: ProviderStatus.failed,
            errorMessage: 'Skipped',
            timeElapsed: stopwatch.elapsed,
          );
        }
      }
      onStatusUpdate?.call(searchStatuses);

      final allCandidates = taskResults.expand((x) => x).toList();

      if (allCandidates.isEmpty) {
        throw const NoStreamsFailure(
          NoStreamsReason.noResults,
          'No results found across add-ons',
        );
      }

      // 4. Deduplicate
      final uniqueMap = <String, StreamCandidate>{};
      for (var c in allCandidates) {
        final dedupeKey = c.uniqueId;

        if (!uniqueMap.containsKey(dedupeKey) ||
            c.seeds > uniqueMap[dedupeKey]!.seeds) {
          uniqueMap[dedupeKey] = c;
        }
      }
      final candidates = uniqueMap.values.toList();

      // Cache only complete searches: a skipped or failed provider would
      // otherwise hide its results for the whole cache duration (STR-05).
      // Saved before finalization (availability check and ranking).
      final isComplete = searchStatuses.every(
        (s) => s.status == ProviderStatus.finished,
      );
      if (isComplete) {
        _searchCache[cacheKey] = _CachedSearch(
          candidates: List.from(candidates),
          context: context,
          timestamp: DateTime.now(),
        );
      }

      final finalized = await _finalizeResults(candidates, context: context);

      return StreamSearchResult(candidates: finalized, isAnime: isAnime);
    } catch (e, st) {
      if (e is NoStreamsFailure) rethrow;
      throw NoStreamsFailure(
        NoStreamsReason.linkFailed,
        'Stream search failed: $e',
        cause: e,
        stackTrace: st,
      );
    } finally {
      statusTimer?.cancel();
    }
  }

  /// Performs availability checks, filtering, and ranking.
  Future<List<StreamCandidate>> _finalizeResults(
    List<StreamCandidate> candidates, {
    required StreamSearchContext context,
  }) async {
    var results = List<StreamCandidate>.from(candidates);

    // 1. Proactive Debrid Availability Check
    if (_debridService != null && _debridService.isEnabled) {
      final hashes = results
          .where((c) => c.infoHash.isNotEmpty)
          .map((c) => c.infoHash)
          .toSet()
          .toList();

      if (hashes.isNotEmpty) {
        AppLogger.debug(
          _logTag,
          'Checking availability for ${hashes.length} hashes on ${_debridService.name}',
        );

        final detailed = await _debridService.checkDetailedAvailability(hashes);

        results = results.map((c) {
          final providers = detailed[c.infoHash.toLowerCase()];
          if (providers != null && providers.isNotEmpty) {
            final updatedCachedOn = Map<String, bool>.from(c.cachedOn);
            for (final p in providers) {
              updatedCachedOn[p] = true;
            }
            return c.copyWith(cachedOn: updatedCachedOn);
          }
          return c;
        }).toList();
      }
    }

    // 2. Drop junk (smart filter) and streams above the maximum resolution
    results = StreamFilter.apply(
      results,
      smartFilter: _settings.smartSearchFilter,
      maxResolution: _maxResolution,
    );

    // 3. Rank and Sort
    final preferredLanguage =
        (context.isAnime && _settings.splitAnimePreferences)
        ? _settings.animeAudioLanguage
        : _settings.playerLanguage;

    return StreamRanker.rank(results, preferredLanguage: preferredLanguage);
  }

  Future<ResolvedStream?> resolveStream(
    StreamCandidate candidate, {
    int? season,
    int? episode,
    int? fileId,
  }) async {
    // Guard against non-VOD sources
    if (candidate.kind != StreamSourceKind.vod) {
      AppLogger.debug(
        _logTag,
        'Ignoring non-VOD candidate kind=${candidate.kind}',
      );
      return null;
    }

    // Stremio addons usually return direct URLs
    if (candidate.url != null && candidate.url!.isNotEmpty) {
      if (_linkCheck != null && _isAddonLink(candidate)) {
        final refusal = await _linkCheck.errorVideoReason(
          candidate.url!,
          headers: candidate.headers,
        );
        if (refusal != null) {
          throw DebridFileFailure(
            refusal,
            '${candidate.provider} sent its error video (${refusal.name})',
          );
        }
      }
      return ResolvedStream(
        url: candidate.url!,
        provider: candidate.provider,
        candidate: candidate,
        headers: candidate.headers,
      );
    }

    // Fallback to Debrid for magnets (the anime torrent feed)
    if (candidate.magnet.isNotEmpty &&
        _debridService != null &&
        _debridService.isEnabled) {
      return _debridService.resolve(
        candidate,
        season: season,
        episode: episode,
        fileId: fileId,
      );
    }

    return null;
  }

  static String? _nonEmpty(Object? id) =>
      id is String && id.isNotEmpty ? id : null;

  /// Only add-on links can lead to an add-on's error video; the built-in
  /// sources' links aren't checked.
  bool _isAddonLink(StreamCandidate candidate) =>
      _sources.any((s) => s is StremioSource && s.name == candidate.provider);
}

/// Result of a stream search, containing the candidates and metadata.
class StreamSearchResult {
  final List<StreamCandidate> candidates;
  final bool isAnime;

  StreamSearchResult({required this.candidates, this.isAnime = false});
}

class _CachedSearch {
  final List<StreamCandidate> candidates;
  final StreamSearchContext context;
  final DateTime timestamp;

  _CachedSearch({
    required this.candidates,
    required this.context,
    required this.timestamp,
  });
}
