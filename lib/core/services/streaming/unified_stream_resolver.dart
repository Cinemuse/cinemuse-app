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
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';

final unifiedStreamResolverProvider = Provider((ref) {
  // Only watch settings that affect streaming sources and ranking
  final settings = ref.watch(settingsProvider.select((s) => (
    s.installedAddons,
    s.enableAnimeTosho,
    s.enableVixSrc,
    s.enableRealDebrid,
    s.realDebridKey,
    s.smartSearchFilter,
    s.playerLanguage,
    s.splitAnimePreferences,
    s.animeAudioLanguage,
  )));
  
  // Create a minimal UserSettings object for the constructor to avoid watching the whole thing
  final userSettings = UserSettings(
    installedAddons: settings.$1,
    enableAnimeTosho: settings.$2,
    enableVixSrc: settings.$3,
    enableRealDebrid: settings.$4,
    realDebridKey: settings.$5,
    smartSearchFilter: settings.$6,
    playerLanguage: settings.$7,
    splitAnimePreferences: settings.$8,
    animeAudioLanguage: settings.$9,
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

  Future<List<StreamCandidate>> searchStreams(
    String queryId, // Can be TMDB ID (digits) or IMDB ID (tt...)
    String type, {
    int? season,
    int? episode,
    void Function(List<ProviderSearchStatus>)? onStatusUpdate,
  }) async {
    Timer? statusTimer;
    final kind = MediaItem.fromString(type);
    final numericId = int.tryParse(queryId);
    
    
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
      final searchStatuses = _sources.map((s) => ProviderSearchStatus(providerName: s.name)).toList();
      onStatusUpdate?.call(searchStatuses);

      // Periodically update UI status
      statusTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        onStatusUpdate?.call(searchStatuses);
      });

      final results = await Future.wait(
        _sources.asMap().entries.map((entry) async {
          final index = entry.key;
          final source = entry.value;
          
          try {
            final candidates = await source.search(context);
            searchStatuses[index] = searchStatuses[index].copyWith(
              status: ProviderStatus.finished,
              resultsCount: candidates.length,
            );
            return candidates;
          } catch (e) {
            searchStatuses[index] = searchStatuses[index].copyWith(
              status: ProviderStatus.failed,
              errorMessage: e.toString(),
            );
            return <StreamCandidate>[];
          }
        }),
      );

      statusTimer.cancel();
      final allCandidates = results.expand((x) => x).toList();

      if (allCandidates.isEmpty) {
        return [];
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
      if (e is StreamingException) rethrow;
      throw StreamResolutionFailedException(e.toString());
    } finally {
      statusTimer?.cancel();
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
