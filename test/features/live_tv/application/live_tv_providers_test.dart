import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/data/epg_storage_service.dart';
import 'package:cinemuse_app/features/live_tv/application/minute_clock_provider.dart';
import 'package:cinemuse_app/features/live_tv/data/live_tv_repository.dart';
import 'package:cinemuse_app/features/live_tv/data/playlist_copy_storage.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_refresh_notifier.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_guide.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_playlist.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_source.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';
import 'package:flutter_riverpod/misc.dart';

const _cinemuseUrl = 'https://example.com/cinemuse.json';
const _myUrl = 'https://example.com/my.xml';

/// Records which guides each load asked for; never calls a server.
class _RecordingRepository extends LiveTvRepository {
  _RecordingRepository() : super(Dio());

  final requests = <List<String>>[];

  @override
  Future<LiveTvLoad<Map<String, List<EpgProgram>>>> fetchEpg({
    required List<LiveTvGuide> guides,
    bool forceRefresh = false,
  }) async {
    requests.add([for (final g in guides) g.urlOrPath]);
    return const LiveTvLoad({});
  }
}

/// Answers every request with a playlist holding Rai 1.
class _Rai1PlaylistAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '#EXTM3U\n#EXTINF:-1,Rai 1\nhttp://example.com/rai1.m3u8\n',
    200,
  );

  @override
  void close({bool force = false}) {}
}

/// Answers with a playlist holding Rai 1 until [isDown], then with a server
/// error.
class _FailingLaterAdapter implements HttpClientAdapter {
  var isDown = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => isDown
      ? ResponseBody.fromString('', 500)
      : ResponseBody.fromString(
          '#EXTM3U\n#EXTINF:-1,Rai 1\nhttp://example.com/rai1.m3u8\n',
          200,
        );

  @override
  void close({bool force = false}) {}
}

/// A clock the test moves by hand.
class _FakeClock extends MinuteClockNotifier {
  _FakeClock(this._start);

  final DateTime _start;

  @override
  DateTime build() => _start;

  void set(DateTime time) => state = time;
}

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingRepository repo;
  late ProviderContainer container;

  void createContainer([List<Override> overrides = const []]) {
    repo = _RecordingRepository();
    container = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        liveTvRepositoryProvider.overrideWithValue(repo),
        cinemuseGuideUrlProvider.overrideWithValue(_cinemuseUrl),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    container.listen(epgDataProvider, (previous, next) {});
  }

  final myGuide = LiveTvGuide(
    id: 'mine',
    name: 'My guide',
    urlOrPath: _myUrl,
    isLocal: false,
  );

  test('loads the Cinemuse guide first, then the saved ones, and nothing '
      'before the saved list is read (REV-115)', () async {
    SharedPreferences.setMockInitialValues({
      'live_tv_custom_guides': [myGuide.encode()],
    });
    createContainer();

    await container.read(epgDataProvider.future);
    await _settle();

    expect(repo.requests.where((r) => r.isNotEmpty), [
      [_cinemuseUrl, _myUrl],
    ]);
  });

  test('a guide turned off is left out and stays off', () async {
    SharedPreferences.setMockInitialValues({
      'live_tv_custom_guides': [myGuide.encode()],
    });
    createContainer();
    await container.read(epgDataProvider.future);
    await _settle();

    await container
        .read(guidesProvider.notifier)
        .toggleEnabled(LiveTvGuide.cinemuseId);
    await container.read(epgDataProvider.future);
    await _settle();

    expect(repo.requests.last, [_myUrl]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('live_tv_cinemuse_guide_enabled'), isFalse);
  });

  test('a copied playlist file whose folder cannot be found fails alone: '
      "the other playlists' channels still load", () async {
    final copied = LiveTvPlaylist(
      id: 'copied',
      name: 'My file',
      // A copy is saved by its file name; the folder is looked up at load
      // time, and a test has no app folders.
      urlOrPath: 'my.m3u',
      isLocal: true,
      type: PlaylistType.m3u,
    );
    SharedPreferences.setMockInitialValues({
      'live_tv_custom_playlists': [copied.encode()],
    });
    final container = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        liveTvRepositoryProvider.overrideWithValue(
          LiveTvRepository(Dio()..httpClientAdapter = _Rai1PlaylistAdapter()),
        ),
        cinemusePlaylistUrlProvider.overrideWithValue(
          'https://example.com/cinemuse.m3u',
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(channelsLoadProvider, (_, _) {});
    await _settle();

    final load = await container.read(channelsLoadProvider.future);

    expect(load.data.single.name, 'Rai 1');
    expect(load.failures.keys, ['copied']);
  });

  group('a downloaded playlist with a saved copy', () {
    late Directory copiesDir;
    late _FailingLaterAdapter adapter;
    late ProviderContainer container;

    final myIptv = LiveTvPlaylist(
      id: 'my-iptv',
      name: 'My IPTV',
      urlOrPath: 'https://example.com/my.m3u',
      isLocal: false,
      type: PlaylistType.m3u,
    );

    setUp(() async {
      copiesDir = Directory.systemTemp.createTempSync('playlist_copies_test');
      addTearDown(() => copiesDir.deleteSync(recursive: true));
      adapter = _FailingLaterAdapter();
      SharedPreferences.setMockInitialValues({
        'live_tv_custom_playlists': [myIptv.encode()],
        'live_tv_cinemuse_playlist_enabled': false,
        'live_tv_cinemuse_guide_enabled': false,
      });
      final copies = PlaylistCopyStorage(directory: () async => copiesDir);
      container = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          liveTvRepositoryProvider.overrideWithValue(
            LiveTvRepository(
              Dio()..httpClientAdapter = adapter,
              playlistCopies: copies,
            ),
          ),
          playlistCopyStorageProvider.overrideWithValue(copies),
          cinemusePlaylistUrlProvider.overrideWithValue(
            'https://example.com/cinemuse.m3u',
          ),
          cinemuseGuideUrlProvider.overrideWithValue(_cinemuseUrl),
        ],
      );
      addTearDown(container.dispose);
      // Like the Live TV tab: the guides have loaded before Refresh.
      container.listen(epgDataProvider, (_, _) {});
      container.listen(selectedChannelProvider, (_, _) {});
      await _settle();
    });

    test(
      'a failed Refresh keeps the channels and the channel playing',
      () async {
        final rai1 = (await container.read(channelsProvider.future)).single;
        container.read(selectedChannelProvider.notifier).select(rai1);

        adapter.isDown = true;
        final failed = await container
            .read(liveTvRefreshProvider.notifier)
            .refresh();
        await _settle();

        expect(failed.playlists, ['My IPTV']);
        expect(
          container.read(playlistFailuresProvider)[myIptv.id]!.usesSavedCopy,
          isTrue,
        );
        expect(
          (await container.read(channelsProvider.future)).map((c) => c.name),
          ['Rai 1'],
        );
        expect(container.read(selectedChannelProvider), same(rai1));
      },
    );

    test('removing the playlist deletes its saved copy', () async {
      await container.read(channelsProvider.future);
      expect(copiesDir.listSync(), isNotEmpty);

      await container.read(playlistsProvider.notifier).remove(myIptv.id);

      expect(copiesDir.listSync(), isEmpty);
    });
  });

  test('the Cinemuse guide can be turned off, not removed', () async {
    SharedPreferences.setMockInitialValues({});
    createContainer();
    await container.read(epgDataProvider.future);
    await _settle();

    await container
        .read(guidesProvider.notifier)
        .remove(LiveTvGuide.cinemuseId);

    expect(container.read(guidesProvider).single.isBuiltIn, isTrue);
  });

  for (final pressedUndo in [true, false]) {
    test('a removed guide goes at once; its saved copy stays until the Undo '
        'message closes (Undo pressed: $pressedUndo)', () async {
      final cacheDir = Directory.systemTemp.createTempSync('guide_undo_test');
      addTearDown(() => cacheDir.deleteSync(recursive: true));
      final savedCopy = File(
        '${cacheDir.path}/${EpgStorageService.cacheFileName(myGuide.id)}',
      )..writeAsStringSync('{}');
      final otherGuide = LiveTvGuide(
        id: 'other',
        name: 'Other guide',
        urlOrPath: 'https://example.com/other.xml',
        isLocal: false,
      );
      SharedPreferences.setMockInitialValues({
        'live_tv_custom_guides': [
          myGuide.copyWith(isEnabled: false).encode(),
          otherGuide.encode(),
        ],
      });
      createContainer([
        epgStorageProvider.overrideWithValue(
          EpgStorageService(cacheDirectory: () async => cacheDir),
        ),
      ]);
      await container.read(epgDataProvider.future);
      await _settle();
      final guides = container.read(guidesProvider.notifier);
      List<String> ids() => [
        for (final g in container.read(guidesProvider)) g.id,
      ];

      final undone = Completer<bool>();
      final removing = guides.remove(myGuide.id, undone: undone.future);
      await _settle();
      expect(ids(), [LiveTvGuide.cinemuseId, 'other']);
      expect(savedCopy.existsSync(), isTrue);

      undone.complete(pressedUndo);
      await removing;
      if (pressedUndo) {
        expect(ids(), [LiveTvGuide.cinemuseId, myGuide.id, 'other']);
        expect(container.read(guidesProvider)[1].isEnabled, isFalse);
        expect(savedCopy.existsSync(), isTrue);
      } else {
        expect(ids(), [LiveTvGuide.cinemuseId, 'other']);
        expect(savedCopy.existsSync(), isFalse);
      }
    });
  }

  test('"now playing" moves on when the clock passes the end (REV-112)', () {
    final start = DateTime(2026, 10, 12, 20);
    const channel = Channel(lcn: 1, name: 'Rai 1', logo: '', epgId: 'rai1');
    final first = EpgProgram(
      name: 'News',
      startTime: start,
      endTime: start.add(const Duration(minutes: 30)),
    );
    final second = EpgProgram(
      name: 'Film',
      startTime: start.add(const Duration(minutes: 30)),
      endTime: start.add(const Duration(hours: 2)),
    );
    final clock = _FakeClock(start.add(const Duration(minutes: 10)));
    final container = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        epgDataProvider.overrideWith(
          (ref) => {
            'rai1': [first, second],
          },
        ),
        minuteClockProvider.overrideWith(() => clock),
      ],
    );
    addTearDown(container.dispose);
    container.listen(epgDataProvider, (previous, next) {});
    final sub = container.listen(currentProgramProvider(channel), (_, _) {});

    return container.read(epgDataProvider.future).then((_) {
      expect(sub.read(), first);
      clock.set(start.add(const Duration(minutes: 31)));
      expect(sub.read(), second);
    });
  });

  test('categories: once each, A to Z, DTT first, none for channels '
      'without one', () async {
    final container = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        channelsProvider.overrideWith(
          (ref) => [
            const Channel(lcn: 1, name: 'Rai 1', logo: '', group: 'DTT'),
            const Channel(lcn: 2, name: 'Sky Sport', logo: '', group: 'Sport'),
            const Channel(lcn: 3, name: 'RTL', logo: '', group: 'Music'),
            const Channel(lcn: 4, name: 'Rai 2', logo: '', group: 'DTT'),
            const Channel(lcn: 5, name: 'Radio', logo: '', group: ''),
            const Channel(lcn: 6, name: 'Other', logo: ''),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(channelCategoriesProvider, (_, _) {});

    await container.read(channelsProvider.future);
    expect(sub.read().value, ['DTT', 'Music', 'Sport']);
  });
}
