import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinemuse_app/features/live_tv/application/custom_playlists_notifier.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_playlist.dart';

const _key = 'live_tv_custom_playlists';

LiveTvPlaylist _playlist(String id) => LiveTvPlaylist(
  id: id,
  name: 'Playlist $id',
  urlOrPath: 'https://example.com/$id.m3u',
  isLocal: false,
  type: PlaylistType.m3u,
);

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer createContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(customPlaylistsProvider, (previous, next) {});
    return container;
  }

  test('one unreadable entry does not wipe the others (REV-114)', () async {
    const unknownType =
        '{"id":"x","name":"X","urlOrPath":"u","isLocal":false,"type":"xspf"}';
    SharedPreferences.setMockInitialValues({
      _key: [_playlist('a').encode(), unknownType],
    });
    final container = createContainer();
    await _settle();

    expect(container.read(customPlaylistsProvider).map((p) => p.id), ['a']);

    await container
        .read(customPlaylistsProvider.notifier)
        .addPlaylist(_playlist('b'));

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key)!;
    expect(saved, hasLength(3));
    expect(saved, contains(unknownType));
  });

  test('a change made while loading is not lost (REV-114)', () async {
    SharedPreferences.setMockInitialValues({
      _key: [_playlist('a').encode()],
    });
    final container = createContainer();

    await container
        .read(customPlaylistsProvider.notifier)
        .addPlaylist(_playlist('b'));
    await _settle();

    expect(container.read(customPlaylistsProvider).map((p) => p.id), [
      'a',
      'b',
    ]);
  });

  test('a local file that cannot be copied throws and adds nothing '
      '(REV-136)', () async {
    SharedPreferences.setMockInitialValues({
      _key: [_playlist('a').encode()],
    });
    final container = createContainer();
    await _settle();

    // No app folder in tests: the copy fails like a full or locked disk.
    await expectLater(
      container
          .read(customPlaylistsProvider.notifier)
          .addLocalPlaylist(File('missing.m3u')),
      throwsA(isA<AppFailure>()),
    );

    expect(container.read(customPlaylistsProvider).map((p) => p.id), ['a']);
  });
}
