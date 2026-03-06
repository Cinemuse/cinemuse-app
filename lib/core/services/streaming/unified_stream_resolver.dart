import 'package:cinemuse_app/core/services/streaming/debrid/base_debrid_service.dart';
import 'package:cinemuse_app/core/services/streaming/models/media_context.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/streaming/ranking/stream_ranker.dart';
import 'package:cinemuse_app/core/services/streaming/sources/base_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/core/services/streaming/sources/stremio_source.dart';
import 'package:cinemuse_app/core/services/streaming/sources/dummy_source.dart';
import 'package:cinemuse_app/core/services/streaming/debrid/real_debrid_service.dart';
import 'package:cinemuse_app/core/services/tmdb_service.dart';
import 'package:cinemuse_app/core/services/kitsu_mapping_service.dart';

final unifiedStreamResolverProvider = Provider((ref) {
  final settings = ref.watch(settingsProvider);
  final dio = ref.read(dioProvider);

  final sources = [
    StremioSource(dio, "https://torrentio.strem.fun", name: 'Torrentio'),
    // DummySource(), // Ready to be un-commented for testing modularity or adding new ones
  ];

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
      // 1. Resolve Media Details and IDs
      final details = await _tmdbService.getMediaDetails(queryId, type);
      if (details == null) throw Exception("Could not fetch media details");

      final tmdbId = int.tryParse(queryId) ?? int.tryParse(details['id'].toString());
      String? imdbId = details['external_ids']?['imdb_id'] ?? details['imdb_id'];
      if (imdbId == null && tmdbId != null) {
        imdbId = await _tmdbService.getImdbId(tmdbId, type);
      }

      if (imdbId == null) throw Exception("Could not resolve IMDB ID");

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
      final searchFutures = _sources.map((source) => source.search(context));
      final rawResults = await Future.wait(searchFutures);
      final allCandidates = rawResults.expand((x) => x).toList();

      if (allCandidates.isEmpty) return [];

      // 4. Deduplicate by InfoHash
      final uniqueMap = <String, StreamCandidate>{};
      for (var c in allCandidates) {
        final hash = c.infoHash.toLowerCase();
        if (!uniqueMap.containsKey(hash) || c.seeds > uniqueMap[hash]!.seeds) {
          uniqueMap[hash] = c;
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
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> resolveStream(
    StreamCandidate candidate, {
    int? season,
    int? episode,
    int? fileId,
  }) async {
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
          candidate.magnet,
          season: season,
          episode: episode,
          absoluteEpisode: candidate.absoluteEpisode,
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
