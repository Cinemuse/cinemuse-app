import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
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

class _FakeSettingsNotifier extends StateNotifier<UserSettings>
    implements SettingsNotifier {
  _FakeSettingsNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('passes the subtitle languages on to the resolver (REV-24)', () {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => _FakeSettingsNotifier(
            const UserSettings(
              subtitleLanguage: 'it',
              animeSubtitleLanguage: 'ja',
            ),
          ),
        ),
        dioProvider.overrideWithValue(Dio()),
        tmdbServiceProvider.overrideWithValue(_MockTmdbService()),
        kitsuMappingServiceProvider.overrideWithValue(
          _MockKitsuMappingService(),
        ),
        mediaRepositoryProvider.overrideWithValue(_MockMediaRepository()),
      ],
    );
    addTearDown(container.dispose);

    final resolver = container.read(unifiedStreamResolverProvider);

    expect(resolver.settings.subtitleLanguage, 'it');
    expect(resolver.settings.animeSubtitleLanguage, 'ja');
  });
}
