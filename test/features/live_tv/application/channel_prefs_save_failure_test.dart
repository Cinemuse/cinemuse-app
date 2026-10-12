import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/live_tv/application/channel_prefs_notifiers.dart';

// Own file: SharedPreferences keeps one instance per test run, and here it
// must come from a storage where every write fails.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async {
            if (call.method.startsWith('getAll')) return <String, Object>{};
            throw PlatformException(code: 'disk-full');
          },
        );
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(channelFilterProvider, (previous, next) {});
    container.listen(favoriteChannelIdsProvider, (previous, next) {});
    container.listen(recentChannelIdsProvider, (previous, next) {});
    return container;
  }

  test('a failed filter save puts the old filter back and throws', () async {
    final container = createContainer();

    await expectLater(
      container.read(channelFilterProvider.notifier).toggleCategory('Sport'),
      throwsA(isA<UnknownFailure>()),
    );
    expect(container.read(channelFilterProvider).isActive, isFalse);
  });

  test('a failed favorite save puts the old set back and throws', () async {
    final container = createContainer();

    await expectLater(
      container.read(favoriteChannelIdsProvider.notifier).toggle('a'),
      throwsA(isA<UnknownFailure>()),
    );
    expect(container.read(favoriteChannelIdsProvider), isEmpty);
  });

  test('a failed recents save is only logged', () async {
    final container = createContainer();

    await container.read(recentChannelIdsProvider.notifier).push('a');

    expect(container.read(recentChannelIdsProvider), isEmpty);
  });
}
