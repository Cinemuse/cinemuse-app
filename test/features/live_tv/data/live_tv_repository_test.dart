import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/features/live_tv/data/epg_storage_service.dart';
import 'package:cinemuse_app/features/live_tv/data/live_tv_repository.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_playlist.dart';

const _epgUrl = 'https://example.com/epg.json';

/// Answers no request until two have started: if playlists were downloaded
/// one after another, the first would wait forever.
class _TwoAtOnceAdapter implements HttpClientAdapter {
  var _started = 0;
  final _bothStarted = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (++_started == 2) _bothStarted.complete();
    await _bothStarted.future;
    final name = options.uri.pathSegments.last;
    return ResponseBody.fromString(
      '#EXTM3U\n#EXTINF:-1,$name\nhttp://example.com/$name.m3u8\n',
      200,
      headers: {
        Headers.contentTypeHeader: ['text/plain'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Answers every request with [body].
class _FixedAdapter implements HttpClientAdapter {
  final String body;
  _FixedAdapter(this.body);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(body, 200);

  @override
  void close({bool force = false}) {}
}

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

  test('downloads playlists at the same time (REV-117)', () async {
    final dio = Dio()..httpClientAdapter = _TwoAtOnceAdapter();
    final repo = LiveTvRepository(dio, defaultEpgUrl: _epgUrl);
    LiveTvPlaylist remote(String name) => LiveTvPlaylist(
      name: name,
      urlOrPath: 'https://example.com/$name',
      isLocal: false,
      type: PlaylistType.m3u,
    );

    final channels = await repo
        .fetchChannels(customPlaylists: [remote('one'), remote('two')])
        .timeout(const Duration(seconds: 5));

    expect(channels.map((c) => c.name), ['one', 'two']);
  });

  test('drops DASH links where they crash the player (REV-118)', () async {
    await File('${dir.path}/a.m3u').writeAsString('''#EXTM3U
#EXTINF:-1 tvg-id="dash",Dash only
http://example.com/live/manifest.MPD?token=1
#EXTINF:-1 tvg-id="mixed",Mixed
http://example.com/mixed.mpd
#EXTINF:-1 tvg-id="mixed",Mixed
http://example.com/mixed.m3u8
''');
    final playlists = [localPlaylist('a.m3u', PlaylistType.m3u)];

    final skipped = await LiveTvRepository(
      Dio(),
      defaultEpgUrl: _epgUrl,
      isDashSkipped: true,
    ).fetchChannels(customPlaylists: playlists);
    final kept = await LiveTvRepository(
      Dio(),
      defaultEpgUrl: _epgUrl,
      isDashSkipped: false,
    ).fetchChannels(customPlaylists: playlists);

    expect(skipped.single.name, 'Mixed');
    expect(skipped.single.links.single.url, 'http://example.com/mixed.m3u8');
    expect(kept, hasLength(2));
  });

  test('a bad value skips only that link or channel (REV-124)', () async {
    await File('${dir.path}/a.json').writeAsString(
      jsonEncode({
        'channels': [
          {
            'name': 'Rai 1',
            'lcn': '5',
            'links': [
              {'url': 'http://example.com/rai1.m3u8'},
              {'quality': 'HD'},
              'not a link',
            ],
          },
          {'name': 'No links', 'links': 'x'},
          'not a channel',
          {
            'name': 'Rai 2',
            'epg_id': 102,
            'links': [
              {'url': 'http://example.com/rai2.m3u8'},
            ],
          },
        ],
      }),
    );
    final repo = LiveTvRepository(Dio(), defaultEpgUrl: _epgUrl);

    final channels = await repo.fetchChannels(
      customPlaylists: [localPlaylist('a.json', PlaylistType.json)],
    );

    expect(channels.map((c) => c.name), ['Rai 1', 'Rai 2']);
    expect(channels.first.lcn, 5);
    expect(channels.first.links.single.url, 'http://example.com/rai1.m3u8');
    expect(channels.last.epgId, '102');
  });

  test('reads Latin-1 files and files with a BOM (REV-124)', () async {
    await File('${dir.path}/latin1.m3u').writeAsBytes(
      latin1.encode('#EXTM3U\n#EXTINF:-1,Rete Città\nhttp://example.com/a\n'),
    );
    await File('${dir.path}/bom.json').writeAsBytes(
      utf8.encode(
        '\uFEFF[{"name":"Bom","links":[{"url":"http://example.com/b"}]}]',
      ),
    );
    final repo = LiveTvRepository(Dio(), defaultEpgUrl: _epgUrl);

    final channels = await repo.fetchChannels(
      customPlaylists: [
        localPlaylist('latin1.m3u', PlaylistType.m3u),
        localPlaylist('bom.json', PlaylistType.json),
      ],
    );

    expect(channels.map((c) => c.name), ['Rete Città', 'Bom']);
  });

  test(
    'a guide download with no programs keeps the old guide (REV-124)',
    () async {
      final storage = EpgStorageService(cacheDirectory: () async => dir);
      final now = DateTime.now();
      await storage.saveCachedEpg(_epgUrl, {
        'rai1': [
          EpgProgram(
            name: 'News',
            startTime: now,
            endTime: now.add(const Duration(hours: 1)),
          ),
        ],
      });
      final dio = Dio()
        ..httpClientAdapter = _FixedAdapter('<html>Server error</html>');
      final repo = LiveTvRepository(
        dio,
        defaultEpgUrl: _epgUrl,
        epgStorage: storage,
      );

      final epg = await repo.fetchEpg(forceRefresh: true);

      expect(epg['rai1']?.single.name, 'News');
    },
  );
}
