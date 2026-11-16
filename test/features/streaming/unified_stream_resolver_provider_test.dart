import 'package:cinemuse_app/core/data/server_addresses_model.dart';
import 'package:cinemuse_app/core/data/server_addresses_repository.dart';
import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/streaming/anime/anime_mapping_service.dart';
import 'package:cinemuse_app/features/streaming/models/stremio_addon.dart';
import 'package:cinemuse_app/features/streaming/sources/anime_torrent_source.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

class _MockTmdbService extends Mock implements TmdbService {}

class _MockAnimeMappingService extends Mock implements AnimeMappingService {}

class _MockMediaRepository extends Mock implements MediaRepository {}

class _FakeSettingsNotifier extends SettingsNotifier {
  _FakeSettingsNotifier([this.initial = const UserSettings()]);

  final UserSettings initial;

  @override
  UserSettings build() => initial;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer containerWith(UserSettings settings) {
    final container = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        settingsProvider.overrideWith(() => _FakeSettingsNotifier(settings)),
        serverAddressesProvider.overrideWith(
          (ref) async => ServerAddresses.fromRows([
            for (final (site, name) in [
              (ServerAddress.movieSite, 'Movie Site'),
              (ServerAddress.animeSite, 'Anime Site'),
              (ServerAddress.animeTorrents, 'Torrent Feed'),
            ])
              {
                'key': site.key,
                'address': 'https://${site.name}.example',
                'display_name': name,
              },
          ]),
        ),
        dioProvider.overrideWithValue(Dio()),
        tmdbServiceProvider.overrideWithValue(_MockTmdbService()),
        animeMappingServiceProvider.overrideWithValue(
          _MockAnimeMappingService(),
        ),
        mediaRepositoryProvider.overrideWithValue(_MockMediaRepository()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('passes the subtitle languages on to the resolver (REV-24)', () {
    final container = containerWith(
      const UserSettings(subtitleLanguage: 'it', animeSubtitleLanguage: 'ja'),
    );

    final resolver = container.read(unifiedStreamResolverProvider);

    expect(resolver.settings.subtitleLanguage, 'it');
    expect(resolver.settings.animeSubtitleLanguage, 'ja');
  });

  // REV-80: the switch is on by default, but torrents need debrid.
  test('leaves the anime torrent feed out without a debrid service', () {
    final container = containerWith(const UserSettings());

    final sources = container.read(unifiedStreamResolverProvider).sources;

    expect(sources.whereType<AnimeTorrentSource>(), isEmpty);
  });

  test('uses the anime torrent feed with TorBox only', () {
    final container = containerWith(
      const UserSettings(enableTorBox: true, torBoxKey: 'key'),
    );

    final sources = container.read(unifiedStreamResolverProvider).sources;

    expect(sources.whereType<AnimeTorrentSource>(), hasLength(1));
  });

  test("the built-in sources are named from the server's list", () async {
    final container = containerWith(
      const UserSettings(enableTorBox: true, torBoxKey: 'key'),
    );
    await container.read(serverAddressesProvider.future);

    final names = container
        .read(unifiedStreamResolverProvider)
        .sources
        .map((s) => s.name);

    expect(names, containsAll(['Movie Site', 'Anime Site', 'Torrent Feed']));
  });

  // REV-319: an add-on with its own debrid key follows that service's switch.
  group('add-ons set up with a debrid service', () {
    StremioAddon addon(String name, String baseUrl) => StremioAddon(
      id: name,
      name: name,
      baseUrl: baseUrl,
      resources: const [
        {'name': 'stream'},
      ],
    );

    final torrentioRd = addon(
      'Torrentio RD',
      'https://torrentio.strem.fun/providers=yts%7Crealdebrid=secret',
    );
    final mediaFusionRd = addon(
      'MediaFusion | ElfHosted RD',
      'https://mediafusion.elfhosted.com/D-encrypted',
    );
    final torBoxAddon = addon('TorBox', 'https://stremio.torbox.app/secret');
    final plain = addon('WebStreamr', 'https://webstreamr.hayd.uk/%7B%7D');
    final all = [torrentioRd, mediaFusionRd, torBoxAddon, plain];

    final cases = [
      (
        what: 'no debrid on: only the plain add-on',
        settings: UserSettings(installedAddons: all, realDebridKey: 'key'),
        expected: ['WebStreamr'],
      ),
      (
        what: 'Real-Debrid on: the Real-Debrid ones too',
        settings: UserSettings(installedAddons: all, enableRealDebrid: true),
        expected: ['Torrentio RD', 'MediaFusion | ElfHosted RD', 'WebStreamr'],
      ),
      (
        what: 'TorBox on: the TorBox one too',
        settings: UserSettings(installedAddons: all, enableTorBox: true),
        expected: ['TorBox', 'WebStreamr'],
      ),
    ];

    for (final c in cases) {
      test(c.what, () {
        final names = containerWith(c.settings)
            .read(unifiedStreamResolverProvider)
            .sources
            .map((s) => s.name)
            .where((n) => all.any((a) => a.name == n));

        expect(names, c.expected);
      });
    }
  });
}
