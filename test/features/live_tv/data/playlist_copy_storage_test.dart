import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/features/live_tv/data/playlist_copy_storage.dart';

const _url = 'https://example.com/my.m3u';
const _text = '#EXTM3U\n#EXTINF:-1,Rai 1\nhttp://example.com/rai1.m3u8\n';

void main() {
  late Directory dir;
  late PlaylistCopyStorage storage;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('playlist_copy_test');
    // A folder that doesn't exist yet: the first save makes it.
    storage = PlaylistCopyStorage(
      directory: () async => Directory('${dir.path}/copies'),
    );
  });

  tearDown(() => dir.delete(recursive: true));

  test('gives back the saved text for the same address', () async {
    await storage.save('p', _url, _text);

    expect(await storage.load('p', url: _url), _text);
  });

  test('a copy saved for another address is not used', () async {
    await storage.save('p', 'https://example.com/old.m3u', _text);

    expect(await storage.load('p', url: _url), isNull);
  });

  test('nothing saved: no copy', () async {
    expect(await storage.load('p', url: _url), isNull);
  });

  test('a deleted copy is gone; the other playlists keep theirs', () async {
    await storage.save('p', _url, _text);
    await storage.save('other', _url, _text);

    await storage.delete('p');

    expect(await storage.load('p', url: _url), isNull);
    expect(await storage.load('other', url: _url), _text);
  });
}
