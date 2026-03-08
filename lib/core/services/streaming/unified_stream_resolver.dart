import 'package:meta/meta.dart';
import 'package:cinemuse_app/core/services/streaming/debrid/base_debrid_service.dart';
import 'package:cinemuse_app/core/services/streaming/models/media_context.dart';
import 'package:cinemuse_app/core/services/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/streaming/ranking/stream_ranker.dart';
import 'package:cinemuse_app/core/services/streaming/sources/base_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/core/services/streaming/sources/stremio_source.dart';
import 'package:cinemuse_app/core/services/streaming/sources/animetosho_source.dart';
import 'package:cinemuse_app/core/services/streaming/sources/dummy_source.dart';
import 'package:cinemuse_app/core/services/streaming/debrid/real_debrid_service.dart';
import 'package:cinemuse_app/core/services/media/tmdb_service.dart';
import 'package:cinemuse_app/core/services/anime/kitsu_mapping_service.dart';
import 'package:cinemuse_app/core/services/streaming/models/streaming_exceptions.dart';

final unifiedStreamResolverProvider = Provider((ref) {
  final settings = ref.watch(settingsProvider);
  final dio = ref.read(dioProvider);

  final configs = [...settings.streamingProviders]..sort((a, b) => a.priority.compareTo(b.priority));
  
  final sources = <BaseSource>[];
  for (final config in configs) {
    if (!config.enabled) continue;
    
    switch (config.id) {
      case 'torrentio':
        sources.add(StremioSource(
          dio, 
          "https://torrentio.strem.fun", 
          name: 'Torrentio',
          supportedCategories: config.supportedCategories ?? {'movie', 'tv', 'anime'},
        ));
        break;
      case 'animetosho':
        sources.add(AnimeToshoSource(dio));
        break;
      case 'mediafusion':
        if (settings.mediafusionUrl.isNotEmpty) {
          sources.add(StremioSource(
            dio, 
            settings.mediafusionUrl, 
            name: 'Mediafusion',
            supportedCategories: config.supportedCategories ?? {'movie', 'tv'},
          ));
        }
        break;
    }
  }

  final debridServices = <BaseDebridService>[];
  if (settings.enableRealDebrid && settings.realDebridKey.isNotEmpty) {
    debridServices.add(RealDebridService(dio, settings.realDebridKey));
  }

  return UnifiedStreamResolver(
    sources: sources,
    debridServices: debridServices,
    tmdbService: ref.read(tmdbServiceProvider),
    kitsuMappingService: ref.read(kitsuMappingServiceProvider),
  );
});

class UnifiedStreamResolver {
  final List<BaseSource> _sources;
  final List<BaseDebridService> _debridServices;
  final TmdbService _tmdbService;
  final KitsuMappingService _kitsuMappingService;

  @visibleForTesting
  List<BaseSource> get sources => _sources;

  UnifiedStreamResolver({
    required List<BaseSource> sources,
    required List<BaseDebridService> debridServices,
    required TmdbService tmdbService,
    required KitsuMappingService kitsuMappingService,
  })  : _sources = sources,
        _debridServices = debridServices,
        _tmdbService = tmdbService,
        _kitsuMappingService = kitsuMappingService;

  Future<List<StreamCandidate>> searchStreams(
    String queryId, // Can be TMDB ID (digits) or IMDB ID (tt...)
    String type, {
    int? season,
    int? episode,
  }) async {
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

      // 2. Resolve Anime Mapping if needed
      KitsuMapping? kitsuMapping;
      if (TmdbService.isAnime(details) && tmdbId != null) {
        kitsuMapping = await _kitsuMappingService.getMapping(
          tmdbId: tmdbId,
          type: type,
          season: season,
          episode: episode,
        );
      }
      final context = MediaContext(
        tmdbId: tmdbId.toString(),
        type: type,
        imdbId: imdbId,
        season: season,
        episode: episode,
        kitsuMapping: kitsuMapping,
        isAnime: TmdbService.isAnime(details),
      );

      // 3. Search All Sources
      final searchFutures = _sources.map((source) {
        // Capability check: If the provider doesn't support the requested category, skip it.
        final targetCategory = context.isAnime ? 'anime' : (context.type == 'tv' ? 'tv' : 'movie');
        if (!source.supportedCategories.contains(targetCategory)) {
          return Future.value(<StreamCandidate>[]);
        }

        return source.search(context).catchError((e) {
          print('UnifiedStreamResolver: Source ${source.name} failed: $e');
          // We don't throw here to allow other sources to succeed, 
          // but we log it for the "ProviderSearchException" pattern if we were to aggregate errors.
          return <StreamCandidate>[];
        });
      });
      final rawResults = await Future.wait(searchFutures);
      final allCandidates = rawResults.expand((x) => x).toList();

      if (allCandidates.isEmpty) {
        final targetCategory = context.isAnime ? 'anime' : (context.type == 'tv' ? 'tv' : 'movie');
        final hasCapableProvider = _sources.any((s) => s.supportedCategories.contains(targetCategory));
        
        if (!hasCapableProvider) {
          throw CapabilityMissingException(targetCategory);
        }
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

      // 5. Filter out junk (CAM, 3D, Screener)
      candidates = candidates.where((c) {
        final t = c.title.toLowerCase();
        return !(t.contains('cam') || t.contains(' ts ') || t.contains('hdcam') || 
                 t.contains('screener') || t.contains(' scr ') || t.contains(' 3d ') || t.contains('sbs'));
      }).toList();

      // 6. Check Instant Availability across all Providers
      if (_debridServices.isNotEmpty) {
        // Limit check to top candidates for performance (legacy used top 15)
        final topHashes = candidates.take(20).map((c) => c.infoHash).toList();
        
        final availabilityFutures = _debridServices.map((d) => d.checkAvailability(topHashes));
        final availabilityResults = await Future.wait(availabilityFutures);

        final mergedAvailability = <String, Map<String, bool>>{}; // Hash -> {ProviderName: IsAvailable}
        for (int i = 0; i < _debridServices.length; i++) {
          final providerName = _debridServices[i].name;
          final providerResults = availabilityResults[i];
          providerResults.forEach((hash, isAvailable) {
            mergedAvailability.putIfAbsent(hash, () => {})[providerName] = isAvailable;
          });
        }

        // Apply availability to candidates
        candidates = candidates.map((c) {
          final hash = c.infoHash.toLowerCase();
          final cachedOn = mergedAvailability[hash] ?? {};
          return c.copyWith(cachedOn: cachedOn);
        }).toList();
      }

      // 7. Rank and Sort
      return StreamRanker.rank(candidates);
    } catch (e) {
      print('UnifiedStreamResolver: Search failed: $e');
      if (e is StreamingException) rethrow;
      throw StreamResolutionFailedException(e.toString());
    }
  }

  Future<ResolvedStream?> resolveStream(
    StreamCandidate candidate, {
    int? season,
    int? episode,
    int? fileId,
  }) async {
    // 0. If candidate already has a direct URL (like Mediafusion), return it immediately
    if (candidate.url != null && candidate.url!.isNotEmpty) {
      return ResolvedStream(
        url: candidate.url!,
        provider: candidate.provider,
        candidate: candidate,
      );
    }

    // 1. Prioritize providers where it's already cached
    final cachedProviders = candidate.cachedOn.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    // Reorder debrid services to put cached ones first
    final sortedDebrid = [..._debridServices]..sort((a, b) {
      final aCached = cachedProviders.contains(a.name) ? 1 : 0;
      final bCached = cachedProviders.contains(b.name) ? 1 : 0;
      return bCached.compareTo(aCached);
    });

    for (final service in sortedDebrid) {
      try {
        final result = await service.resolve(
          candidate,
          season: season,
          episode: episode,
          fileId: fileId,
        );
        if (result != null) return result;
      } catch (e) {
        print('UnifiedStreamResolver: Resolve failed for ${service.name}: $e');
      }
    }

    return null;
  }
}
