import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/settings/application/local_settings_service.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/streaming/anime/animeunity_lookup_service.dart';
import 'package:cinemuse_app/features/streaming/anime/kitsu_mapping_service.dart';
import 'package:cinemuse_app/features/streaming/debrid/base_debrid_service.dart';
import 'package:cinemuse_app/features/streaming/debrid/composite_debrid_service.dart';
import 'package:cinemuse_app/features/streaming/debrid/real_debrid_service.dart';
import 'package:cinemuse_app/features/streaming/debrid/torbox_service.dart';
import 'package:cinemuse_app/features/streaming/sources/animetosho_source.dart';
import 'package:cinemuse_app/features/streaming/sources/animeunity_source.dart';
import 'package:cinemuse_app/features/streaming/sources/base_source.dart';
import 'package:cinemuse_app/features/streaming/sources/stremio_source.dart';
import 'package:cinemuse_app/features/streaming/sources/vixsrc_source.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Builds the [UnifiedStreamResolver] from the user's enabled sources and
/// debrid services.
final unifiedStreamResolverProvider = Provider((ref) {
  // Only watch settings that affect streaming sources and ranking
  final settings = ref.watch(
    settingsProvider.select(
      (s) => (
        s.installedAddons,
        s.enableAnimeTosho,
        s.enableVixSrc,
        s.enableAnimeUnity,
        s.enableRealDebrid,
        s.realDebridKey,
        s.enableTorBox,
        s.torBoxKey,
        s.preferredDebridProvider,
        s.smartSearchFilter,
        s.playerLanguage,
        s.splitAnimePreferences,
        s.animeAudioLanguage,
        s.enableAutoSkipProviders,
        s.subtitleLanguage,
        s.animeSubtitleLanguage,
      ),
    ),
  );

  // Create a minimal UserSettings object for the constructor to avoid watching the whole thing
  final userSettings = UserSettings(
    installedAddons: settings.$1,
    enableAnimeTosho: settings.$2,
    enableVixSrc: settings.$3,
    enableAnimeUnity: settings.$4,
    enableRealDebrid: settings.$5,
    realDebridKey: settings.$6,
    enableTorBox: settings.$7,
    torBoxKey: settings.$8,
    preferredDebridProvider: settings.$9,
    smartSearchFilter: settings.$10,
    playerLanguage: settings.$11,
    splitAnimePreferences: settings.$12,
    animeAudioLanguage: settings.$13,
    enableAutoSkipProviders: settings.$14,
    subtitleLanguage: settings.$15,
    animeSubtitleLanguage: settings.$16,
  );

  final maxResolution = ref.watch(
    localSettingsProvider.select((s) => s.maxResolution),
  );

  final dio = ref.read(dioProvider);

  final List<BaseSource> sources = [];

  // Dynamic Stremio Addons
  for (final addon in userSettings.installedAddons) {
    if (!addon.enabled || !addon.isStreamingAddon) {
      continue;
    }

    sources.add(
      StremioSource(
        dio,
        addon.baseUrl,
        name: addon.name,
        supportedCategories: addon.types.toSet(),
        queryParams: addon.queryParams,
      ),
    );
  }

  // Register built-in sources
  if (userSettings.enableAnimeTosho) {
    sources.add(AnimeToshoSource(dio));
  }

  if (userSettings.enableVixSrc) {
    sources.add(VixSrcSource(dio));
  }

  if (userSettings.enableAnimeUnity) {
    sources.add(AnimeUnitySource(dio, AnimeUnityLookupService(dio)));
  }

  final debridServices = <BaseDebridService>[];
  if (userSettings.enableRealDebrid) {
    debridServices.add(RealDebridService(dio, userSettings.realDebridKey));
  }
  if (userSettings.enableTorBox) {
    debridServices.add(TorBoxService(dio, userSettings.torBoxKey));
  }

  final preferredName =
      userSettings.preferredDebridProvider.toLowerCase() == 'torbox'
      ? 'TorBox'
      : 'Real-Debrid';

  final debridService = debridServices.isNotEmpty
      ? CompositeDebridService(debridServices, preferredProvider: preferredName)
      : null;

  return UnifiedStreamResolver(
    sources: sources,
    tmdbService: ref.read(tmdbServiceProvider),
    kitsuMappingService: ref.read(kitsuMappingServiceProvider),
    mediaRepository: ref.read(mediaRepositoryProvider),
    settings: userSettings,
    maxResolution: maxResolution,
    debridService: debridService,
  );
});
