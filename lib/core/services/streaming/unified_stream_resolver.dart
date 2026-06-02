import 'dart:async';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:meta/meta.dart';
import 'package:cinemuse_app/core/services/streaming/debrid/base_debrid_service.dart';
import 'package:cinemuse_app/core/services/streaming/models/provider_search_status.dart';
import 'package:flutter/foundation.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_search_context.dart';
import 'package:cinemuse_app/core/services/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/streaming/ranking/stream_ranker.dart';
import 'package:cinemuse_app/core/services/streaming/sources/base_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/core/services/streaming/models/stremio_addon.dart';
import 'package:cinemuse_app/core/services/streaming/sources/stremio_source.dart';
import 'package:cinemuse_app/core/services/streaming/sources/dummy_source.dart';
import 'package:cinemuse_app/core/services/media/tmdb_service.dart';
import 'package:cinemuse_app/core/services/anime/kitsu_mapping_service.dart';
import 'package:cinemuse_app/core/services/streaming/models/streaming_exceptions.dart';
import 'package:cinemuse_app/core/services/streaming/sources/animetosho_source.dart';
import 'package:cinemuse_app/core/services/streaming/debrid/real_debrid_service.dart';
import 'package:cinemuse_app/core/services/streaming/sources/vixsrc_source.dart';
import 'package:cinemuse_app/core/services/streaming/sources/animeunity_source.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';

final unifiedStreamResolverProvider = Provider((ref) {
  // Only watch settings that affect streaming sources and ranking
  final settings = ref.watch(settingsProvider.select((s) => (
    s.installedAddons,
    s.enableAnimeTosho,
    s.enableVixSrc,
    s.enableAnimeUnity,
    s.enableRealDebrid,
    s.realDebridKey,
    s.smartSearchFilter,
    s.playerLanguage,
    s.splitAnimePreferences,
    s.animeAudioLanguage,
    s.enableAutoSkipProviders,
  )));
  
  // Create a minimal UserSettings object for the constructor to avoid watching the whole thing
  final userSettings = UserSettings(
    installedAddons: settings.$1,
    enableAnimeTosho: settings.$2,
    enableVixSrc: settings.$3,
    enableAnimeUnity: settings.$4,
    enableRealDebrid: settings.$5,
    realDebridKey: settings.$6,
    smartSearchFilter: settings.$7,
    playerLanguage: settings.$8,
    splitAnimePreferences: settings.$9,
    animeAudioLanguage: settings.$10,
    enableAutoSkipProviders: settings.$11,
  );

  final dio = ref.read(dioProvider);
  final sources = <BaseSource>[];
  
  // Dynamic Stremio Addons
  for (final addon in userSettings.installedAddons) {
    if (!addon.enabled || !addon.isStreamingAddon) {
      continue;
    }
    
    sources.add(StremioSource(
      dio, 
      addon.baseUrl,
      name: addon.name,
      supportedCategories: addon.types.toSet(),
      queryParams: addon.queryParams,
    ));
  }
  
  // Native Build-in Sources
  if (userSettings.enableAnimeTosho) {
    sources.add(AnimeToshoSource(dio));
  }

  if (userSettings.enableVixSrc) {
    sources.add(VixSrcSource(dio));
  }

  if (userSettings.enableAnimeUnity) {
    sources.add(AnimeUnitySource(dio, ref.read(kitsuMappingServiceProvider)));
  }

  return UnifiedStreamResolver(
    sources: sources,
    tmdbService: ref.read(tmdbServiceProvider),
    kitsuMappingService: ref.read(kitsuMappingServiceProvider),
    mediaRepository: ref.read(mediaRepositoryProvider),
    settings: userSettings,
    debridService: userSettings.enableRealDebrid 
        ? RealDebridService(dio, userSettings.realDebridKey) 
        : null,
  );
});

class UnifiedStreamResolver {
  final List<BaseSource> _sources;
  final TmdbService _tmdbService;
  final KitsuMappingService _kitsuMappingService;
  final MediaRepository _mediaRepository;
  final UserSettings _settings;
  final BaseDebridService? _debridService;

  // Simple in-memory cache for search results
  final Map<String, _CachedSearch> _searchCache = {};
  static const Duration _cacheDuration = Duration(minutes: 30);

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
    final cacheKey = "$type:$queryId:${season ?? 0}:${episode ?? 0}";
    final cached = _searchCache[cacheKey];
    if (cached == null) return false;
    
    final isExpired = DateTime.now().difference(cached.timestamp) >= _cacheDuration;
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
    final cacheKey = "$type:$queryId:${season ?? 0}:${episode ?? 0}";
    _searchCache.remove(cacheKey);
    debugPrint('UnifiedStreamResolver: Cleared cached results for $cacheKey');
  }

  @visibleForTesting
  List<BaseSource> get sources => _sources;

  UnifiedStreamResolver({
    required List<BaseSource> sources,
    required TmdbService tmdbService,
    required KitsuMappingService kitsuMappingService,
    required MediaRepository mediaRepository,
    required UserSettings settings,
    BaseDebridService? debridService,
  })  : _sources = sources,
        _tmdbService = tmdbService,
        _kitsuMappingService = kitsuMappingService,
        _mediaRepository = mediaRepository,
        _settings = settings,
        _debridService = debridService;

  Future<StreamSearchResult> searchStreams(
    String queryId, // Can be TMDB ID (digits) or IMDB ID (tt...)
    String type, {
    int? season,
    int? episode,
    void Function(List<ProviderSearchStatus>)? onStatusUpdate,
    Future<void>? skipTrigger,
  }) async {
    final cacheKey = "$type:$queryId:${season ?? 0}:${episode ?? 0}";
    final cached = _searchCache[cacheKey];
    
    if (cached != null && DateTime.now().difference(cached.timestamp) < _cacheDuration) {
      debugPrint('UnifiedStreamResolver: Returning cached results for $cacheKey');
      // Proactively check availability again if needed, or return cached ones
      // Since ranking depends on cache status, we might want to re-check if we have a debrid service
      final rankedCandidates = await _finalizeResults(cached.candidates, context: cached.context);
      return StreamSearchResult(candidates: rankedCandidates, isAnime: cached.context.isAnime);
    }

    Timer? statusTimer;
    final kind = MediaItem.fromString(type);
    
    try {
      if (_sources.isEmpty) {
        throw NoProvidersEnabledException();
      }

      // 1. Resolve Media Details and IDs
      final details = await _tmdbService.getMediaDetails(queryId, type);
      if (details == null) throw MediaDetailsResolutionException();

      // Proactively ingest into cache since we have full details
      final item = MediaItem.fromTmdbDetails(details, kind);
      _mediaRepository.saveMediaItem(item).catchError((_) {});

      final tmdbId = int.tryParse(queryId) ?? int.tryParse(details['id'].toString());
      String? imdbId = details['external_ids']?['imdb_id'] ?? details['imdb_id'];
      if (imdbId == null && tmdbId != null) {
        imdbId = await _tmdbService.getImdbId(tmdbId, type);
      }

      if (imdbId == null) throw ImdbIdResolutionException();

      // 2. Resolve Anime Mapping
      final kitsuMapping = tmdbId != null 
          ? await _kitsuMappingService.getMapping(
              tmdbId: tmdbId,
              type: type,
              season: season,
              episode: episode,
            ) 
          : null;

      final isAnime = kitsuMapping != null;
      final context = StreamSearchContext(
        tmdbId: (tmdbId ?? details['id']).toString(),
        imdbId: imdbId,
        type: type,
        season: season,
        episode: episode,
        title: details['title'] ?? details['name'] ?? '',
        mapping: kitsuMapping,
        isAnime: isAnime,
      );

      // 3. Search All Sources
      final stopwatch = Stopwatch()..start();
      final searchStatuses = _sources.map((s) => ProviderSearchStatus(providerName: s.name)).toList();
      onStatusUpdate?.call(searchStatuses);

      // Periodically update UI status
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

      final taskResults = List.generate(_sources.length, (_) => <StreamCandidate>[]);
      final taskFutures = <Future<void>>[];

      for (int i = 0; i < _sources.length; i++) {
        final source = _sources[i];
        final task = () async {
          try {
            final searchFuture = source.search(context);
            final candidates = _settings.enableAutoSkipProviders
                ? await searchFuture.timeout(const Duration(seconds: 30))
                : await searchFuture;
            taskResults[i] = candidates;
            searchStatuses[i] = searchStatuses[i].copyWith(
              status: ProviderStatus.finished,
              resultsCount: candidates.length,
              timeElapsed: stopwatch.elapsed,
            );
            onStatusUpdate?.call(searchStatuses);
          } on TimeoutException catch (e) {
            searchStatuses[i] = searchStatuses[i].copyWith(
              status: ProviderStatus.failed,
              errorMessage: 'Timeout after 30s',
              timeElapsed: stopwatch.elapsed,
            );
            onStatusUpdate?.call(searchStatuses);
          } catch (e) {
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
        await Future.any([
          Future.wait(taskFutures),
          skipTrigger,
        ]);
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
        throw NoResultsFoundException();
      }

      // 4. Deduplicate
      final uniqueMap = <String, StreamCandidate>{};
      for (var c in allCandidates) {
        final dedupeKey = c.uniqueId;
            
        if (!uniqueMap.containsKey(dedupeKey) || c.seeds > uniqueMap[dedupeKey]!.seeds) {
          uniqueMap[dedupeKey] = c;
        }
      }
      var candidates = uniqueMap.values.toList();

      // Save to cache before finalization (availability check and ranking)
      _searchCache[cacheKey] = _CachedSearch(
        candidates: List.from(candidates),
        context: context,
        timestamp: DateTime.now(),
      );

      return StreamSearchResult(
        candidates: await _finalizeResults(candidates, context: context),
        isAnime: isAnime,
      );
    } catch (e) {
      if (e is StreamingException) rethrow;
      throw StreamResolutionFailedException(e.toString());
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
    if (_debridService != null && _debridService!.isEnabled) {
      final hashes = results
          .where((c) => c.infoHash.isNotEmpty)
          .map((c) => c.infoHash)
          .toSet()
          .toList();

      if (hashes.isNotEmpty) {
        debugPrint('UnifiedStreamResolver: Checking availability for ${hashes.length} hashes on ${_debridService!.name}');
        
        // Split into chunks if there are many (RD has limits, though usually 100 is fine)
        final Map<String, bool> availability = {};
        for (var i = 0; i < hashes.length; i += 100) {
          final chunk = hashes.sublist(i, i + 100 > hashes.length ? hashes.length : i + 100);
          final chunkRes = await _debridService!.checkAvailability(chunk);
          availability.addAll(chunkRes);
        }

        results = results.map((c) {
          final isAvailable = availability[c.infoHash.toLowerCase()] ?? false;
          if (isAvailable) {
            final updatedCachedOn = Map<String, bool>.from(c.cachedOn);
            updatedCachedOn[_debridService!.name] = true;
            return c.copyWith(cachedOn: updatedCachedOn);
          }
          return c;
        }).toList();
      }
    }

    // 2. Filter out junk if smart search is enabled
    if (_settings.smartSearchFilter) {
      results = results.where((c) {
        final t = c.title.toLowerCase();
        return !(t.contains('cam') || t.contains(' ts ') || t.contains('hdcam') || 
                 t.contains('screener') || t.contains(' scr ') || t.contains(' 3d ') || t.contains('sbs'));
      }).toList();
    }

    // 3. Rank and Sort
    final preferredLanguage = (context.isAnime && _settings.splitAnimePreferences) 
        ? _settings.animeAudioLanguage 
        : _settings.playerLanguage;
        
    return StreamRanker.rank(results, preferredLanguage: preferredLanguage);
  }

  Future<bool> checkIsAnime(Map<String, dynamic> details, String type) async {
    final tmdbId = int.tryParse(details['id'].toString());
    if (tmdbId == null) return false;

    final kitsuMapping = await _kitsuMappingService.getMapping(
      tmdbId: tmdbId,
      type: type,
    );

    return kitsuMapping != null;
  }

  Future<ResolvedStream?> resolveStream(
    StreamCandidate candidate, {
    int? season,
    int? episode,
    int? fileId,
  }) async {
    // Stremio addons usually return direct URLs
    if (candidate.url != null && candidate.url!.isNotEmpty) {
      return ResolvedStream(
        url: candidate.url!,
        provider: candidate.provider,
        candidate: candidate,
        headers: candidate.headers,
      );
    }
    
    // Fallback to Debrid for magnets (native sources like AnimeTosho)
    if (candidate.magnet.isNotEmpty && _debridService != null && _debridService!.isEnabled) {
      return _debridService!.resolve(
        candidate,
        season: season,
        episode: episode,
      );
    }
    
    return null;
  }
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
