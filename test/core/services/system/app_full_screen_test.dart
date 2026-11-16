import 'package:cinemuse_app/core/application/provider_retry.dart';
import 'package:cinemuse_app/core/services/system/app_full_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_app_window.dart';

void main() {
  late FakeAppWindow window;

  ProviderContainer container({bool startsOn = false}) {
    final c = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        appWindowProvider.overrideWithValue(window),
        if (startsOn)
          appFullScreenProvider.overrideWith(
            () => AppFullScreenNotifier(startsOn: true),
          ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() => window = FakeAppWindow());
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
    test('${platform.name}: F11 fills the screen, and again gives the window '
        'back', () async {
      debugDefaultTargetPlatformOverride = platform;
      final c = container();
      final notifier = c.read(appFullScreenProvider.notifier);

      await notifier.toggle();
      expect(c.read(appFullScreenProvider), isTrue);
      await notifier.toggle();
      expect(c.read(appFullScreenProvider), isFalse);

      expect(window.fullScreenCalls, [true, false]);
    });
  }

  test('started in full screen: the first F11 gives the window back', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final c = container(startsOn: true);
    expect(c.read(appFullScreenProvider), isTrue);

    await c.read(appFullScreenProvider.notifier).toggle();

    expect(window.fullScreenCalls, [false]);
  });

  test('Android: nothing happens (the app already fills the screen)', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final c = container();

    await c.read(appFullScreenProvider.notifier).toggle();

    expect(c.read(appFullScreenProvider), isFalse);
    expect(window.fullScreenCalls, isEmpty);
  });
}
