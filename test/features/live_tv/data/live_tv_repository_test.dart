import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/features/live_tv/data/live_tv_repository.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_playlist.dart';

const _epgUrl = 'https://example.com/epg.json';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('live_tv_repo_test');
  });

  tearDown(() => dir.delete(recursive: true));

  LiveTvPlaylist localPlaylist(String fileName, PlaylistType type) =>
      LiveTvPlaylist(
        name: fileName,
        urlOrPath: '${dir.path}/$fileName',
        isLocal: true,
        type: type,
      );

  test('parses local playlists on a background isolate (PERF-01)', () async {
    await File('${dir.path}/a.m3u').writeAsString('''#EXTM3U
#EXTINF:-1 tvg-id="rai1.it" tvg-chno="1",Rai 1
http://example.com/rai1.m3u8
''');
    await File('${dir.path}/b.json').writeAsString('''[
  {"name": "Rai 2", "lcn": 2, "links": [{"url": "http://example.com/rai2.m3u8"}]}
]''');
    final repo = LiveTvRepository(Dio(), defaultEpgUrl: _epgUrl);

    final channels = await repo.fetchChannels(
      customPlaylists: [
        localPlaylist('a.m3u', PlaylistType.m3u),
        localPlaylist('b.json', PlaylistType.json),
      ],
    );

    expect(channels.map((c) => c.name), ['Rai 1', 'Rai 2']);
    expect(channels.first.links.single.url, 'http://example.com/rai1.m3u8');
  });

  test('skips a broken playlist and keeps the others', () async {
    await File('${dir.path}/bad.json').writeAsString('not json');
    await File('${dir.path}/a.m3u').writeAsString('''#EXTM3U
#EXTINF:-1,Rai 1
http://example.com/rai1.m3u8
''');
    final repo = LiveTvRepository(Dio(), defaultEpgUrl: _epgUrl);

    final channels = await repo.fetchChannels(
      customPlaylists: [
        localPlaylist('bad.json', PlaylistType.json),
        localPlaylist('a.m3u', PlaylistType.m3u),
      ],
    );

    expect(channels.single.name, 'Rai 1');
  });

  test(
    'numbers of a second playlist carry on after the first (REV-113)',
    () async {
      await File('${dir.path}/a.m3u').writeAsString('''#EXTM3U
#EXTINF:-1,Alpha
http://example.com/a.m3u8
#EXTINF:-1,Beta
http://example.com/b.m3u8
''');
      await File('${dir.path}/b.m3u').writeAsString('''#EXTM3U
#EXTINF:-1,Gamma
http://example.com/c.m3u8
''');
      final repo = LiveTvRepository(Dio(), defaultEpgUrl: _epgUrl);

      final channels = await repo.fetchChannels(
        customPlaylists: [
          localPlaylist('a.m3u', PlaylistType.m3u),
          localPlaylist('b.m3u', PlaylistType.m3u),
        ],
      );

      expect(channels.map((c) => c.name), ['Alpha', 'Beta', 'Gamma']);
      expect(channels.map((c) => c.lcn).toSet(), hasLength(3));
    },
  );
}
