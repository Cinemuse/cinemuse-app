import 'package:cinemuse_app/core/utils/platform_info.dart';
import 'package:cinemuse_app/features/settings/application/local_settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/subtitle_style.dart';
import 'package:cinemuse_app/features/streaming/models/stream_metadata.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

// REV-85: device settings.
void main() {
  late ProviderContainer container;

  Future<LocalSettings> load() async {
    container.read(localSettingsProvider);
    await pumpEventQueue();
    return container.read(localSettingsProvider);
  }

  setUp(() {
    container = ProviderContainer(retry: noProviderRetry);
    addTearDown(container.dispose);
  });

  test('reads an old index-based max resolution once, then by name', () async {
    SharedPreferences.setMockInitialValues({'max_resolution': 2});

    expect((await load()).maxResolution, VideoResolution.r1080p);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('max_resolution_name'), 'r1080p');
    expect(prefs.containsKey('max_resolution'), false);
  });

  test('saves max resolution by name', () async {
    SharedPreferences.setMockInitialValues({});
    await load();

    await container
        .read(localSettingsProvider.notifier)
        .updateMaxResolution(VideoResolution.r720p);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('max_resolution_name'), 'r720p');
  });

  test('the Undo time is saved and read back after a restart', () async {
    SharedPreferences.setMockInitialValues({});
    expect((await load()).undoTime, const Duration(seconds: 4));

    await container
        .read(localSettingsProvider.notifier)
        .updateUndoTime(Duration.zero);

    container.dispose();
    container = ProviderContainer(retry: noProviderRetry);
    expect((await load()).undoTime, Duration.zero);
  });

  test('Start in full screen is off at first, then saved and read back at '
      'the next start', () async {
    SharedPreferences.setMockInitialValues({});
    expect((await load()).startFullScreen, isFalse);
    expect(await LocalSettingsNotifier.readStartFullScreen(), isFalse);

    await container
        .read(localSettingsProvider.notifier)
        .updateStartFullScreen(true);

    expect(await LocalSettingsNotifier.readStartFullScreen(), isTrue);
    container.dispose();
    container = ProviderContainer(retry: noProviderRetry);
    expect((await load()).startFullScreen, isTrue);
  });

  test('the Screen size is saved and read back after a restart', () async {
    SharedPreferences.setMockInitialValues({});
    expect((await load()).screenPercent, 100);

    await container
        .read(localSettingsProvider.notifier)
        .updateScreenPercent(125);

    container.dispose();
    container = ProviderContainer(retry: noProviderRetry);
    expect((await load()).screenPercent, 125);
  });

  test('a TV starts at 2/3 size; a saved choice wins', () async {
    PlatformInfo.setTvForTesting(true);
    addTearDown(() => PlatformInfo.setTvForTesting(null));
    SharedPreferences.setMockInitialValues({});
    expect((await load()).screenPercent, 67);

    SharedPreferences.setMockInitialValues({'screen_percent': 90});
    container.dispose();
    container = ProviderContainer(retry: noProviderRetry);
    expect((await load()).screenPercent, 90);
  });

  test('a preview shows the style without saving it', () async {
    SharedPreferences.setMockInitialValues({});
    await load();

    container
        .read(localSettingsProvider.notifier)
        .previewSubtitleStyle(const SubtitleStyle(fontSize: 40));

    expect(container.read(localSettingsProvider).subtitleStyle.fontSize, 40);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('subtitle_font_size'), false);
  });

  test('a change made before the load ends is not overwritten', () async {
    SharedPreferences.setMockInitialValues({'max_resolution_name': 'r2160p'});

    container.read(localSettingsProvider);
    // Before the load (scheduled after build) has run.
    await container
        .read(localSettingsProvider.notifier)
        .updateMaxResolution(VideoResolution.r720p);
    await pumpEventQueue();

    expect(
      container.read(localSettingsProvider).maxResolution,
      VideoResolution.r720p,
    );
  });
}
