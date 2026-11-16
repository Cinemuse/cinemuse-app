import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinemuse_app/features/live_tv/application/playlists_notifier.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_playlist.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

const _key = 'live_tv_custom_playlists';
const _cinemuseUrl = 'https://example.com/cinemuse.m3u';
const _cinemuse = LiveTvPlaylist.cinemuseId;

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
    final container = ProviderContainer(
      retry: noProviderRetry,
      overrides: [cinemusePlaylistUrlProvider.overrideWithValue(_cinemuseUrl)],
    );
    addTearDown(container.dispose);
    container.listen(playlistsProvider, (previous, next) {});
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

    expect(container.read(playlistsProvider).map((p) => p.id), [
      _cinemuse,
      'a',
    ]);

    await container.read(playlistsProvider.notifier).add(_playlist('b'));

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

    await container.read(playlistsProvider.notifier).add(_playlist('b'));
    await _settle();

    expect(container.read(playlistsProvider).map((p) => p.id), [
      _cinemuse,
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
          .read(playlistsProvider.notifier)
          .addLocalFile(File('missing.m3u')),
      throwsA(isA<AppFailure>()),
    );

    expect(container.read(playlistsProvider).map((p) => p.id), [
      _cinemuse,
      'a',
    ]);
  });

  test('the Cinemuse playlist comes first, on, and is not saved with the '
      "user's own (REV-336)", () async {
    SharedPreferences.setMockInitialValues({});
    final container = createContainer();
    await _settle();

    final cinemuse = container.read(playlistsProvider).single;
    expect(cinemuse.id, _cinemuse);
    expect(cinemuse.isBuiltIn, isTrue);
    expect(cinemuse.isEnabled, isTrue);
    expect(cinemuse.urlOrPath, _cinemuseUrl);

    await container.read(playlistsProvider.notifier).add(_playlist('b'));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(_key), [_playlist('b').encode()]);
  });

  test('the Cinemuse playlist is never removed, only turned off, and stays '
      'off (REV-336)', () async {
    SharedPreferences.setMockInitialValues({});
    final container = createContainer();
    await _settle();
    final playlists = container.read(playlistsProvider.notifier);

    await playlists.remove(_cinemuse);
    expect(container.read(playlistsProvider).map((p) => p.id), [_cinemuse]);

    await playlists.toggleEnabled(_cinemuse);
    expect(container.read(playlistsProvider).single.isEnabled, isFalse);

    final next = createContainer();
    await _settle();
    expect(next.read(playlistsProvider).single.isEnabled, isFalse);
  });
}
