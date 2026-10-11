import 'package:cinemuse_app/features/settings/application/local_settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/subtitle_style.dart';
import 'package:cinemuse_app/features/streaming/models/stream_metadata.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// REV-85: device settings.
void main() {
  late ProviderContainer container;

  Future<LocalSettings> load() async {
    container.read(localSettingsProvider);
    await pumpEventQueue();
    return container.read(localSettingsProvider);
  }

  setUp(() {
    container = ProviderContainer();
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
