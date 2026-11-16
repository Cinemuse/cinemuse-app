import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/live_tv/data/epg_storage_service.dart';
import 'package:cinemuse_app/features/live_tv/data/live_tv_repository.dart';
import 'package:cinemuse_app/features/live_tv/data/playlist_copy_storage.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_guide.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_playlist.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_source.dart';

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

/// Answers every request with [status] and no body.
class _StatusAdapter implements HttpClientAdapter {
  final int status;
  _StatusAdapter(this.status);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString('', status);

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
    final repo = LiveTvRepository(Dio());

    final channels = (await repo.fetchChannels(
      playlists: [
        localPlaylist('a.m3u', PlaylistType.m3u),
        localPlaylist('b.json', PlaylistType.json),
      ],
    )).data;

    expect(channels.map((c) => c.name), ['Rai 1', 'Rai 2']);
    expect(channels.first.links.single.url, 'http://example.com/rai1.m3u8');
  });

  test('skips a broken playlist and keeps the others', () async {
    await File('${dir.path}/bad.json').writeAsString('not json');
    await File('${dir.path}/a.m3u').writeAsString('''#EXTM3U
#EXTINF:-1,Rai 1
http://example.com/rai1.m3u8
''');
    final repo = LiveTvRepository(Dio());

    final channels = (await repo.fetchChannels(
      playlists: [
        localPlaylist('bad.json', PlaylistType.json),
        localPlaylist('a.m3u', PlaylistType.m3u),
      ],
    )).data;

    expect(channels.single.name, 'Rai 1');
  });

  test('each playlist that fails is reported by its id, with why; the '
      'others still load', () async {
    await File('${dir.path}/a.m3u').writeAsString('''#EXTM3U
#EXTINF:-1,Rai 1
http://example.com/rai1.m3u8
''');
    await File('${dir.path}/bad.json').writeAsString('not json');
    await File('${dir.path}/empty.m3u').writeAsString('#EXTM3U\n');
    final good = localPlaylist('a.m3u', PlaylistType.m3u);
    final missing = localPlaylist('gone.m3u', PlaylistType.m3u);
    final notJson = localPlaylist('bad.json', PlaylistType.json);
    final empty = localPlaylist('empty.m3u', PlaylistType.m3u);
    final remote = LiveTvPlaylist(
      name: 'remote',
      urlOrPath: 'https://example.com/remote.m3u',
      isLocal: false,
      type: PlaylistType.m3u,
    );
    final repo = LiveTvRepository(
      Dio()..httpClientAdapter = _StatusAdapter(404),
    );

    final load = await repo.fetchChannels(
      playlists: [good, missing, notJson, empty, remote],
    );

    expect(load.data.single.name, 'Rai 1');
    expect(
      load.failures.keys,
      unorderedEquals([missing.id, notJson.id, empty.id, remote.id]),
    );
    expect(load.failures[missing.id]!.failure, isA<NotFoundFailure>());
    expect(load.failures[notJson.id]!.failure, isA<ValidationFailure>());
    expect(load.failures[empty.id]!.failure, isA<ValidationFailure>());
    final serverFailure = load.failures[remote.id]!.failure;
    expect(serverFailure, isA<ServerFailure>());
    expect((serverFailure as ServerFailure).statusCode, 404);
    expect(serverFailure.toString(), isNot(contains('example.com')));
  });

  group('a downloaded playlist that fails', () {
    const rai1Playlist =
        '#EXTM3U\n#EXTINF:-1,Rai 1\nhttp://example.com/rai1.m3u8\n';
    final remote = LiveTvPlaylist(
      name: 'remote',
      urlOrPath: 'https://example.com/remote.m3u',
      isLocal: false,
      type: PlaylistType.m3u,
    );
    late PlaylistCopyStorage copies;

    setUp(() => copies = PlaylistCopyStorage(directory: () async => dir));

    Future<LiveTvLoad<List<Channel>>> load(
      HttpClientAdapter adapter, [
      LiveTvPlaylist? playlist,
    ]) => LiveTvRepository(
      Dio()..httpClientAdapter = adapter,
      playlistCopies: copies,
    ).fetchChannels(playlists: [playlist ?? remote]);

    for (final (why, adapter, failureType) in [
      ('a server error', _StatusAdapter(500), isA<ServerFailure>()),
      (
        'a page with no channels',
        _FixedAdapter('<html>Server error</html>'),
        isA<ValidationFailure>(),
      ),
    ]) {
      test('($why) shows the channels of its last good download', () async {
        await load(_FixedAdapter(rai1Playlist));

        final failed = await load(adapter);

        expect(failed.data.single.name, 'Rai 1');
        final failure = failed.failures[remote.id]!;
        expect(failure.failure, failureType);
        expect(failure.usesSavedCopy, isTrue);
      });
    }

    test(
      'with no saved copy shows nothing and is reported as failed',
      () async {
        final failed = await load(_StatusAdapter(500));

        expect(failed.data, isEmpty);
        expect(failed.failures[remote.id]!.usesSavedCopy, isFalse);
      },
    );

    test(
      'a local file gets no saved copy: it is already on the device',
      () async {
        final file = localPlaylist('a.m3u', PlaylistType.m3u);
        await File(file.urlOrPath).writeAsString(rai1Playlist);
        await load(_StatusAdapter(500), file);
        await File(file.urlOrPath).delete();

        final failed = await load(_StatusAdapter(500), file);

        expect(failed.data, isEmpty);
        expect(failed.failures[file.id]!.usesSavedCopy, isFalse);
      },
    );
  });

  test('the same name in two playlists is one row, '
      'whatever their guide ids', () async {
    await File('${dir.path}/a.m3u').writeAsString('''#EXTM3U
#EXTINF:-1 tvg-id="Rai1.it",Rai 1
http://example.com/a-rai1.m3u8
''');
    await File('${dir.path}/b.m3u').writeAsString('''#EXTM3U
#EXTINF:-1 tvg-id="rai-1",RAI 1 HD
http://example.com/b-rai1.m3u8
''');
    final repo = LiveTvRepository(Dio());

    final channels = (await repo.fetchChannels(
      playlists: [
        localPlaylist('a.m3u', PlaylistType.m3u),
        localPlaylist('b.m3u', PlaylistType.m3u),
      ],
    )).data;

    final channel = channels.single;
    expect(channel.name, 'Rai 1');
    expect(channel.epgId, 'Rai1.it');
    expect(channel.links, hasLength(2));
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
      final repo = LiveTvRepository(Dio());

      final channels = (await repo.fetchChannels(
        playlists: [
          localPlaylist('a.m3u', PlaylistType.m3u),
          localPlaylist('b.m3u', PlaylistType.m3u),
        ],
      )).data;

      expect(channels.map((c) => c.name), ['Alpha', 'Beta', 'Gamma']);
      expect(channels.map((c) => c.lcn).toSet(), hasLength(3));
    },
  );

  test('downloads playlists at the same time (REV-117)', () async {
    final dio = Dio()..httpClientAdapter = _TwoAtOnceAdapter();
    final repo = LiveTvRepository(dio);
    LiveTvPlaylist remote(String name) => LiveTvPlaylist(
      name: name,
      urlOrPath: 'https://example.com/$name',
      isLocal: false,
      type: PlaylistType.m3u,
    );

    final channels = await repo
        .fetchChannels(playlists: [remote('one'), remote('two')])
        .timeout(const Duration(seconds: 5));

    expect(channels.data.map((c) => c.name), ['one', 'two']);
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
    final repo = LiveTvRepository(Dio());

    final channels = (await repo.fetchChannels(
      playlists: [localPlaylist('a.json', PlaylistType.json)],
    )).data;

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
    final repo = LiveTvRepository(Dio());

    final channels = (await repo.fetchChannels(
      playlists: [
        localPlaylist('latin1.m3u', PlaylistType.m3u),
        localPlaylist('bom.json', PlaylistType.json),
      ],
    )).data;

    expect(channels.map((c) => c.name), ['Rete Città', 'Bom']);
  });

  test(
    'a guide download with no programs keeps the old guide (REV-124)',
    () async {
      final storage = EpgStorageService(cacheDirectory: () async => dir);
      final guide = _guide('g', _epgUrl);
      await storage.saveCachedEpg(guide.id, _epgUrl, {
        'rai1': [_program('News')],
      });
      final dio = Dio()
        ..httpClientAdapter = _FixedAdapter('<html>Server error</html>');
      final repo = LiveTvRepository(dio, epgStorage: storage);

      final epg = await repo.fetchEpg(guides: [guide], forceRefresh: true);

      expect(epg.data['rai1']?.single.name, 'News');
      final failure = epg.failures[guide.id]!;
      expect(failure.failure, isA<ValidationFailure>());
      expect(failure.usesSavedCopy, isTrue);
    },
  );

  test('a guide that fails with no saved copy: no programmes, reported as '
      'failed', () async {
    final storage = EpgStorageService(cacheDirectory: () async => dir);
    final guide = _guide('g', _epgUrl);
    final repo = LiveTvRepository(
      Dio()..httpClientAdapter = _StatusAdapter(500),
      epgStorage: storage,
    );

    final epg = await repo.fetchEpg(guides: [guide]);

    expect(epg.data, isEmpty);
    final failure = epg.failures[guide.id]!;
    expect(failure.failure, isA<ServerFailure>());
    expect(failure.usesSavedCopy, isFalse);
  });

  test('two guides: the one higher in the list wins a shared channel, '
      'each keeps its own channels', () async {
    final storage = EpgStorageService(cacheDirectory: () async => dir);
    final first = _guide('first', 'https://example.com/first.json');
    final second = _guide('second', 'https://example.com/second.xml');
    await storage.saveCachedEpg(first.id, first.urlOrPath, {
      'rai1': [_program('TG1 from the first')],
    });
    await storage.saveCachedEpg(second.id, second.urlOrPath, {
      'rai1': [_program('TG1 from the second')],
      'skytg24': [_program('Sky TG24 news')],
    });
    final repo = LiveTvRepository(Dio(), epgStorage: storage);

    final epg = await repo.fetchEpg(guides: [first, second]);

    expect(epg.data['rai1']?.single.name, 'TG1 from the first');
    expect(epg.data['skytg24']?.single.name, 'Sky TG24 news');
    expect(epg.failures, isEmpty);
  });

  test('no guide on: an empty guide, nothing downloaded', () async {
    final repo = LiveTvRepository(
      Dio()..httpClientAdapter = _FixedAdapter('unused'),
      epgStorage: EpgStorageService(cacheDirectory: () async => dir),
    );

    expect((await repo.fetchEpg(guides: const [])).data, isEmpty);
  });
}

LiveTvGuide _guide(String id, String url) =>
    LiveTvGuide(id: id, name: id, urlOrPath: url, isLocal: false);

EpgProgram _program(String name) {
  final now = DateTime.now();
  return EpgProgram(
    name: name,
    startTime: now,
    endTime: now.add(const Duration(hours: 1)),
  );
}
