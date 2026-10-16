import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/streaming/anime/kitsu_mapping_service.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockTmdbService extends Mock implements TmdbService {}

class _MockKitsuMappingService extends Mock implements KitsuMappingService {}

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
      overrides: [
        settingsProvider.overrideWith(() => _FakeSettingsNotifier(settings)),
        dioProvider.overrideWithValue(Dio()),
        tmdbServiceProvider.overrideWithValue(_MockTmdbService()),
        kitsuMappingServiceProvider.overrideWithValue(
          _MockKitsuMappingService(),
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
  test('leaves AnimeTosho out without a debrid service', () {
    final container = containerWith(const UserSettings());

    final names = container
        .read(unifiedStreamResolverProvider)
        .sources
        .map((s) => s.name);

    expect(names, isNot(contains('AnimeTosho')));
  });

  test('uses AnimeTosho with TorBox only', () {
    final container = containerWith(
      const UserSettings(enableTorBox: true, torBoxKey: 'key'),
    );

    final names = container
        .read(unifiedStreamResolverProvider)
        .sources
        .map((s) => s.name);

    expect(names, contains('AnimeTosho'));
  });
}
