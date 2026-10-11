import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/streaming/subtitles/subtitle_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSettingsNotifier extends StateNotifier<UserSettings>
    implements SettingsNotifier {
  _FakeSettingsNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeSettingsNotifier settings;
  late ProviderContainer container;

  setUp(() {
    settings = _FakeSettingsNotifier(
      const UserSettings(openSubtitlesKey: 'key-1'),
    );
    container = ProviderContainer(
      overrides: [settingsProvider.overrideWith((ref) => settings)],
    );
    addTearDown(container.dispose);
  });

  test('builds the providers once, not on every read (REV-35)', () {
    final first = container.read(subtitleProvidersProvider);

    expect(first, hasLength(1));
    expect(container.read(subtitleProvidersProvider), same(first));

    // Another setting changing doesn't rebuild them either.
    settings.state = settings.state.copyWith(subtitleLanguage: 'it');
    expect(container.read(subtitleProvidersProvider), same(first));
  });

  test('rebuilds the providers when the OpenSubtitles key changes', () {
    final first = container.read(subtitleProvidersProvider);

    settings.state = settings.state.copyWith(openSubtitlesKey: 'key-2');

    expect(container.read(subtitleProvidersProvider), isNot(same(first)));
  });

  test('no key, no providers', () {
    settings.state = settings.state.copyWith(openSubtitlesKey: '');

    expect(container.read(subtitleServiceProvider).hasActiveProviders, false);
  });
}
