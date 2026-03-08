import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/core/services/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/core/services/streaming/models/streaming_provider_config.dart';
import 'package:cinemuse_app/features/profile/data/profile_repository.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:cinemuse_app/core/services/media/tmdb_service.dart';
import 'package:cinemuse_app/core/services/anime/kitsu_mapping_service.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}
class MockRef extends Mock implements Ref {}
class MockDio extends Mock implements Dio {}
class MockTmdbService extends Mock implements TmdbService {}
class MockKitsuMappingService extends Mock implements KitsuMappingService {}

class SettingsNotifierMock extends SettingsNotifier {
  SettingsNotifierMock(UserSettings initial) : super(MockProfileRepository(), MockRef()) {
    state = initial;
  }
  
  @override
  Future<void> initSettings() async {}
}

void main() {
  late MockDio mockDio;
  late MockTmdbService mockTmdb;
  late MockKitsuMappingService mockKitsu;

  setUp(() {
    mockDio = MockDio();
    mockTmdb = MockTmdbService();
    mockKitsu = MockKitsuMappingService();
  });

  group('Provider Management Integration', () {
    test('unifiedStreamResolverProvider should filter disabled providers', () {
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(mockDio),
          tmdbServiceProvider.overrideWithValue(mockTmdb),
          kitsuMappingServiceProvider.overrideWithValue(mockKitsu),
          settingsProvider.overrideWith((ref) => SettingsNotifierMock(
            UserSettings(
              streamingProviders: [
                const StreamingProviderConfig(id: 'torrentio', name: 'Torrentio', priority: 0, enabled: false),
                const StreamingProviderConfig(id: 'animetosho', name: 'AnimeTosho', priority: 1, enabled: true),
              ],
            ),
          )),
        ],
      );

      final resolver = container.read(unifiedStreamResolverProvider);
      
      expect(resolver.sources.length, equals(1));
      expect(resolver.sources.first.name, equals('AnimeTosho'));
    });

    test('unifiedStreamResolverProvider should honor priority ordering', () {
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(mockDio),
          tmdbServiceProvider.overrideWithValue(mockTmdb),
          kitsuMappingServiceProvider.overrideWithValue(mockKitsu),
          settingsProvider.overrideWith((ref) => SettingsNotifierMock(
            UserSettings(
              streamingProviders: [
                const StreamingProviderConfig(id: 'animetosho', name: 'AnimeTosho', priority: 0, enabled: true),
                const StreamingProviderConfig(id: 'torrentio', name: 'Torrentio', priority: 1, enabled: true),
              ],
            ),
          )),
        ],
      );

      final resolver = container.read(unifiedStreamResolverProvider);
      
      expect(resolver.sources.length, equals(2));
      expect(resolver.sources[0].name, equals('AnimeTosho'));
      expect(resolver.sources[1].name, equals('Torrentio'));
    });
  });
}
