import 'package:cinemuse_app/core/data/server_addresses_model.dart';
import 'package:cinemuse_app/core/data/server_addresses_repository.dart';
import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/settings/application/local_settings_service.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/streaming/anime/builtin_anime_lookup_service.dart';
import 'package:cinemuse_app/features/streaming/anime/anime_mapping_service.dart';
import 'package:cinemuse_app/features/streaming/debrid/addon_link_check_service.dart';
import 'package:cinemuse_app/features/streaming/debrid/base_debrid_service.dart';
import 'package:cinemuse_app/features/streaming/debrid/composite_debrid_service.dart';
import 'package:cinemuse_app/features/streaming/debrid/real_debrid_service.dart';
import 'package:cinemuse_app/features/streaming/debrid/torbox_service.dart';
import 'package:cinemuse_app/features/streaming/sources/anime_torrent_source.dart';
import 'package:cinemuse_app/features/streaming/sources/builtin_anime_source.dart';
import 'package:cinemuse_app/features/streaming/sources/base_source.dart';
import 'package:cinemuse_app/features/streaming/sources/stremio_source.dart';
import 'package:cinemuse_app/features/streaming/sources/builtin_movie_source.dart';
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
        s.enableAnimeTorrents,
        s.enableMovieSite,
        s.enableAnimeSite,
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
    enableAnimeTorrents: settings.$2,
    enableMovieSite: settings.$3,
    enableAnimeSite: settings.$4,
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
  Future<ServerAddresses> loadAddresses() =>
      ref.read(serverAddressesProvider.future);
  // The built-in sources' names, shown while searching and on their streams.
  final names =
      ref.watch(serverAddressesProvider).value ?? ServerAddresses.empty;

  final List<BaseSource> sources = [];

  // Dynamic Stremio Addons
  for (final addon in userSettings.installedAddons) {
    if (!addon.enabled || !addon.isStreamingAddon) {
      continue;
    }
    // An add-on with its own debrid key would still use that service: its
    // switch here must turn it off too (REV-319).
    if ((addon.usesRealDebrid && !userSettings.enableRealDebrid) ||
        (addon.usesTorBox && !userSettings.enableTorBox)) {
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
  if (userSettings.isAnimeTorrentsActive) {
    sources.add(
      AnimeTorrentSource(
        dio,
        loadAddresses,
        name: names.name(ServerAddress.animeTorrents),
      ),
    );
  }

  if (userSettings.enableMovieSite) {
    sources.add(
      BuiltInMovieSource(
        dio,
        loadAddresses,
        name: names.name(ServerAddress.movieSite),
      ),
    );
  }

  if (userSettings.enableAnimeSite) {
    sources.add(
      BuiltInAnimeSource(
        dio,
        BuiltInAnimeLookupService(dio, loadAddresses),
        loadAddresses,
        name: names.name(ServerAddress.animeSite),
      ),
    );
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
    animeMappingService: ref.read(animeMappingServiceProvider),
    mediaRepository: ref.read(mediaRepositoryProvider),
    settings: userSettings,
    maxResolution: maxResolution,
    debridService: debridService,
    linkCheck: AddonLinkCheckService(dio),
  );
});
