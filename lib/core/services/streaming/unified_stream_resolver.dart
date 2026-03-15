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

final unifiedStreamResolverProvider = Provider((ref) {
  final settings = ref.watch(settingsProvider);
  final dio = ref.read(dioProvider);

  final sources = <BaseSource>[];
  
  // Dynamic Stremio Addons
  for (final addon in settings.installedAddons) {
    if (!addon.enabled || !addon.isStreamingAddon) {
      debugPrint('UnifiedStreamResolver: Skipping addon ${addon.name} (enabled: ${addon.enabled}, streaming: ${addon.isStreamingAddon})');
      continue;
    }
    
    debugPrint('UnifiedStreamResolver: Adding source ${addon.name} (BaseUrl: ${addon.baseUrl})');
    sources.add(StremioSource(
      dio, 
      addon.baseUrl,
      name: addon.name,
      supportedCategories: addon.types.toSet(),
      queryParams: addon.queryParams,
    ));
  }
  
  // Native Build-in Sources
  if (settings.enableAnimeTosho) {
    debugPrint('UnifiedStreamResolver: Adding native source AnimeTosho');
    sources.add(AnimeToshoSource(dio));
  }

  if (settings.enableVixSrc) {
    debugPrint('UnifiedStreamResolver: Adding native source VixSrc');
    sources.add(VixSrcSource(dio));
  }

  return UnifiedStreamResolver(
    sources: sources,
    tmdbService: ref.read(tmdbServiceProvider),
    kitsuMappingService: ref.read(kitsuMappingServiceProvider),
    settings: settings,
    debridService: settings.enableRealDebrid 
        ? RealDebridService(dio, settings.realDebridKey) 
        : null,
  );
});

class UnifiedStreamResolver {
  final List<BaseSource> _sources;
  final TmdbService _tmdbService;
  final KitsuMappingService _kitsuMappingService;
  final UserSettings _settings;
  final BaseDebridService? _debridService;

  @visibleForTesting
  List<BaseSource> get sources => _sources;

  UnifiedStreamResolver({
    required List<BaseSource> sources,
    required TmdbService tmdbService,
    required KitsuMappingService kitsuMappingService,
    required UserSettings settings,
    BaseDebridService? debridService,
  })  : _sources = sources,
        _tmdbService = tmdbService,
        _kitsuMappingService = kitsuMappingService,
        _settings = settings,
        _debridService = debridService;

  Future<List<StreamCandidate>> searchStreams(
    String queryId, // Can be TMDB ID (digits) or IMDB ID (tt...)
    String type, {
    int? season,
    int? episode,
    void Function(List<ProviderSearchStatus>)? onStatusUpdate,
  }) async {
    Timer? statusTimer;
    try {
      if (_sources.isEmpty) {
        throw NoProvidersEnabledException();
      }

      // 1. Resolve Media Details and IDs
      final details = await _tmdbService.getMediaDetails(queryId, type);
      if (details == null) throw MediaDetailsResolutionException();

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

      final context = StreamSearchContext(
        tmdbId: tmdbId.toString(),
        type: type,
        title: details['title'] ?? details['name'] ?? 'Unknown',
        imdbId: imdbId,
        season: season,
        episode: episode,
        episodeName: details['episode_name'],
        seasonName: details['season_name'],
        mapping: kitsuMapping,
        isAnime: kitsuMapping != null,
      );

      // 3. Search All Sources
      final targetCategory = context.isAnime ? 'anime' : (context.type == 'tv' ? 'tv' : 'movie');
      final capableSources = _sources.where((s) => s.supportedCategories.contains(targetCategory)).toList();
      
      debugPrint('UnifiedStreamResolver: Target Category: $targetCategory');
      debugPrint('UnifiedStreamResolver: Total Sources: ${_sources.length}');
      debugPrint('UnifiedStreamResolver: Capable Sources: ${capableSources.map((s) => s.name).toList()}');

      if (capableSources.isEmpty) {
        throw CapabilityMissingException(targetCategory);
      }

      final statuses = <String, ProviderSearchStatus>{};
      for (final s in capableSources) {
        statuses[s.name] = ProviderSearchStatus(providerName: s.name);
      }

      void emitStatuses() {
        if (onStatusUpdate != null) {
          onStatusUpdate(statuses.values.toList());
        }
      }

      emitStatuses();

      var elapsedMilliseconds = 0;
      statusTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        elapsedMilliseconds += 100;
        bool changed = false;
        for (final k in statuses.keys) {
          if (statuses[k]!.status == ProviderStatus.searching) {
            statuses[k] = statuses[k]!.copyWith(timeElapsed: Duration(milliseconds: elapsedMilliseconds));
            changed = true;
          }
        }
        if (changed) emitStatuses();
      });

      final searchFutures = capableSources.map((source) {
        return source.search(context).then((results) {
          statuses[source.name] = statuses[source.name]!.copyWith(
            status: ProviderStatus.finished,
            resultsCount: results.length,
          );
          emitStatuses();
          return results;
        }).catchError((e) {
          // TODO: Use a proper logger
          statuses[source.name] = statuses[source.name]!.copyWith(
            status: ProviderStatus.failed,
            errorMessage: e.toString(),
          );
          emitStatuses();
          return <StreamCandidate>[];
        });
      });
      final rawResults = await Future.wait(searchFutures);
      statusTimer.cancel();
      
      final allCandidates = rawResults.expand((x) => x).toList();

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

      // 5. Filter out junk if smart search is enabled
      if (_settings.smartSearchFilter) {
        candidates = candidates.where((c) {
          final t = c.title.toLowerCase();
          return !(t.contains('cam') || t.contains(' ts ') || t.contains('hdcam') || 
                   t.contains('screener') || t.contains(' scr ') || t.contains(' 3d ') || t.contains('sbs'));
        }).toList();
      }

      // 6. Rank and Sort
      final preferredLanguage = (context.isAnime && _settings.splitAnimePreferences) 
          ? _settings.animeAudioLanguage 
          : _settings.playerLanguage;
          
      return StreamRanker.rank(candidates, preferredLanguage: preferredLanguage);
    } catch (e) {
      statusTimer?.cancel();
      if (e is StreamingException) rethrow;
      throw StreamResolutionFailedException(e.toString());
    }
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
