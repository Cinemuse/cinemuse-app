import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/streaming/subtitles/subtitle_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSettingsNotifier extends SettingsNotifier {
  _FakeSettingsNotifier([this.initial = const UserSettings()]);

  final UserSettings initial;

  @override
  UserSettings build() => initial;

  UserSettings get current => state;

  void set(UserSettings settings) => state = settings;
}

void main() {
  late _FakeSettingsNotifier settings;
  late ProviderContainer container;

  setUp(() {
    settings = _FakeSettingsNotifier(
      const UserSettings(openSubtitlesKey: 'key-1'),
    );
    container = ProviderContainer(
      overrides: [settingsProvider.overrideWith(() => settings)],
    );
    addTearDown(container.dispose);
  });

  test('builds the providers once, not on every read (REV-35)', () {
    final first = container.read(subtitleProvidersProvider);

    expect(first, hasLength(1));
    expect(container.read(subtitleProvidersProvider), same(first));

    // Another setting changing doesn't rebuild them either.
    settings.set(settings.current.copyWith(subtitleLanguage: 'it'));
    expect(container.read(subtitleProvidersProvider), same(first));
  });

  test('rebuilds the providers when the OpenSubtitles key changes', () {
    final first = container.read(subtitleProvidersProvider);

    settings.set(settings.current.copyWith(openSubtitlesKey: 'key-2'));

    expect(container.read(subtitleProvidersProvider), isNot(same(first)));
  });

  test('no key, no providers', () {
    container.read(settingsProvider); // a Notifier has state once read
    settings.set(settings.current.copyWith(openSubtitlesKey: ''));

    expect(container.read(subtitleServiceProvider).hasActiveProviders, false);
  });
}
