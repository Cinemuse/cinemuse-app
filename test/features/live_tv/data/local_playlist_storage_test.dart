import 'dart:io';

import 'package:cinemuse_app/features/live_tv/data/local_playlist_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late Directory playlistsDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('playlist_storage_test');
    playlistsDir = Directory(p.join(tempDir.path, 'playlists'))..createSync();
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  File sourceFile(String folder, String content) {
    final dir = Directory(p.join(tempDir.path, folder))..createSync();
    return File(p.join(dir.path, 'playlist.m3u'))..writeAsStringSync(content);
  }

  test('keeps the original file name when it is free', () async {
    final copy = await LocalPlaylistStorage.copyIntoDir(
      sourceFile('a', 'first'),
      playlistsDir,
    );

    expect(p.basename(copy.path), 'playlist.m3u');
  });

  test(
    'a second playlist with the same name does not overwrite the first',
    () async {
      final first = await LocalPlaylistStorage.copyIntoDir(
        sourceFile('a', 'first'),
        playlistsDir,
      );
      final second = await LocalPlaylistStorage.copyIntoDir(
        sourceFile('b', 'second'),
        playlistsDir,
      );
      final third = await LocalPlaylistStorage.copyIntoDir(
        sourceFile('c', 'third'),
        playlistsDir,
      );

      expect(p.basename(second.path), 'playlist (1).m3u');
      expect(p.basename(third.path), 'playlist (2).m3u');
      expect(first.readAsStringSync(), 'first');
      expect(second.readAsStringSync(), 'second');
      expect(third.readAsStringSync(), 'third');
    },
  );
}
