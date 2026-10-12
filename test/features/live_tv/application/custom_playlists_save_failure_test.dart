import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/live_tv/application/custom_playlists_notifier.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_playlist.dart';

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

  test('a failed save puts the old list back and throws (REV-222)', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(customPlaylistsProvider, (previous, next) {});
    final playlist = LiveTvPlaylist(
      name: 'A',
      urlOrPath: 'https://example.com/a.m3u',
      isLocal: false,
      type: PlaylistType.m3u,
    );

    await expectLater(
      container.read(customPlaylistsProvider.notifier).addPlaylist(playlist),
      throwsA(isA<UnknownFailure>()),
    );
    expect(container.read(customPlaylistsProvider), isEmpty);
  });
}
