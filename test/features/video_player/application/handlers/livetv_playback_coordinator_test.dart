import 'dart:async';

import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/livetv_playback_coordinator.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlayer extends Mock implements Player {}

class _MockNativePlayer extends Mock implements NativePlayer {}

class _MockPlayerStream extends Mock implements PlayerStream {}

class _MockVideoController extends Mock implements VideoController {}

/// A coordinator on a mocked player; [opened] lists every URL it opens, and
/// [videoTracks] the picture size (mpv's `vid`) each open asked for.
class _Harness {
  final player = _MockPlayer();
  final buffering = StreamController<bool>.broadcast();
  final position = StreamController<Duration>.broadcast();
  final tracks = StreamController<Tracks>.broadcast();
  final height = StreamController<int?>.broadcast();
  final opened = <String>[];
  final videoTracks = <String>[];
  CinemaPlayerState? state;

  /// How many times the lower-size suggestion was shown.
  var suggestions = 0;
  late final LiveTvPlaybackCoordinator coordinator;

  /// mpv's track list as JSON: the stream's sizes.
  String trackList = '[]';

  _Harness() {
    final stream = _MockPlayerStream();
    final native = _MockNativePlayer();
    when(() => player.stream).thenReturn(stream);
    when(() => player.platform).thenReturn(native);
    when(() => native.setProperty(any(), any())).thenAnswer((invocation) async {
      if (invocation.positionalArguments.first == 'vid') {
        videoTracks.add(invocation.positionalArguments[1] as String);
      }
    });
    when(() => stream.buffering).thenAnswer((_) => buffering.stream);
    when(() => stream.position).thenAnswer((_) => position.stream);
    when(() => stream.duration).thenAnswer((_) => const Stream.empty());
    when(() => stream.width).thenAnswer((_) => const Stream.empty());
    when(() => stream.tracks).thenAnswer((_) => tracks.stream);
    when(() => stream.height).thenAnswer((_) => height.stream);
    when(() => player.open(any(), play: any(named: 'play'))).thenAnswer((
      invocation,
    ) async {
      opened.add((invocation.positionalArguments.first as Media).uri);
    });
    when(player.stop).thenAnswer((_) async {});

    coordinator = LiveTvPlaybackCoordinator(
      player: player,
      controller: _MockVideoController(),
      getSettings: () => const UserSettings(),
      isMounted: () => true,
      getCurrentState: () => state,
      onStateChanged: (s) => state = s,
      onError: (e, _) => fail('unexpected error: $e'),
      unavailableMessage: () => 'Stream unavailable',
      lowerSizeSuggestion: () {
        suggestions++;
        return 'Try a lower quality';
      },
      readTrackList: () async => trackList,
    );
  }

  void dispose() {
    coordinator.dispose();
    unawaited(buffering.close());
    unawaited(position.close());
    unawaited(tracks.close());
    unawaited(height.close());
  }

  /// The stream says its sizes, like Rai 1's: 1080p (track 1), 720p
  /// (track 3), 432p (track 5).
  void sayRaiSizes(FakeAsync async) {
    trackList = _raiTrackList;
    tracks.add(const Tracks());
    async.flushMicrotasks();
  }

  /// The stream loads and then plays long enough for pauses to count.
  void playSettled(FakeAsync async) {
    buffering.add(true);
    buffering.add(false);
    async.elapse(const Duration(seconds: 11));
  }

  void pause(FakeAsync async) {
    buffering.add(true);
    buffering.add(false);
    async.elapse(const Duration(seconds: 5));
  }

  /// Both links fail once: one full round.
  void failRound(FakeAsync async) {
    unawaited(coordinator.handleFailover('404', isConnectionError: true));
    async.flushMicrotasks();
    unawaited(coordinator.handleFailover('404', isConnectionError: true));
    async.flushMicrotasks();
  }
}

const _raiTrackList = '''[
  {"id": 1, "type": "video", "selected": true, "demux-h": 1080, "hls-bitrate": 5340630},
  {"id": 1, "type": "audio", "selected": true, "lang": "ita"},
  {"id": 3, "type": "video", "selected": false, "demux-h": 720, "hls-bitrate": 2793078},
  {"id": 5, "type": "video", "selected": false, "demux-h": 432, "hls-bitrate": 1365331}
]''';

Channel _channel() => Channel(
  lcn: 1,
  name: 'One',
  logo: '',
  links: [
    StreamLink(url: 'https://one/a.m3u8'),
    StreamLink(url: 'https://one/b.m3u8'),
  ],
);

void main() {
  setUpAll(() => registerFallbackValue(Media('https://fallback')));

  test('a dead channel waits between rounds, then says so (REV-145)', () {
    fakeAsync((async) {
      final h = _Harness();
      addTearDown(h.dispose);
      unawaited(h.coordinator.changeChannel(_channel()));
      async.flushMicrotasks();
      expect(h.opened, ['https://one/a.m3u8']);

      h.failRound(async);
      // Link b was tried at once; after it, nothing reopens right away.
      expect(h.opened, ['https://one/a.m3u8', 'https://one/b.m3u8']);
      async.elapse(const Duration(seconds: 1));
      expect(h.opened, hasLength(2));
      async.elapse(const Duration(seconds: 1));
      expect(h.opened, hasLength(3));

      h.failRound(async);
      async.elapse(const Duration(seconds: 4));
      h.failRound(async);
      async.elapse(const Duration(minutes: 1));

      expect(h.state?.error, 'Stream unavailable');
      expect(h.state?.isResolving, isFalse);
      verify(h.player.stop).called(1);
      final openedBefore = h.opened.length;

      // The dead stream's late errors don't restart the loop.
      unawaited(h.coordinator.handleFailover('404', isConnectionError: true));
      async.elapse(const Duration(minutes: 1));
      expect(h.opened, hasLength(openedBefore));

      // Picking the channel again starts fresh.
      unawaited(h.coordinator.changeChannel(_channel()));
      async.flushMicrotasks();
      expect(h.opened, hasLength(openedBefore + 1));
      expect(h.state?.error, isNull);
    });
  });

  test('the state carries the channel and the link it plays (REV-154)', () {
    fakeAsync((async) {
      final h = _Harness();
      addTearDown(h.dispose);
      final channel = _channel();
      unawaited(h.coordinator.changeChannel(channel));
      async.flushMicrotasks();

      expect(h.state?.live.channel, same(channel));
      expect(h.state?.live.link?.url, 'https://one/a.m3u8');

      unawaited(h.coordinator.switchLiveSource(channel.links[1]));
      async.flushMicrotasks();

      expect(h.state?.live.channel, same(channel));
      expect(h.state?.live.link?.url, 'https://one/b.m3u8');
    });
  });

  test('the playlist order decides the first link, not its quality', () {
    fakeAsync((async) {
      final h = _Harness();
      addTearDown(h.dispose);
      unawaited(
        h.coordinator.changeChannel(
          Channel(
            lcn: 1,
            name: 'One',
            logo: '',
            links: [
              StreamLink(url: 'https://one/sd.m3u8'),
              StreamLink(url: 'https://one/hd.m3u8', quality: StreamQuality.hd),
            ],
          ),
        ),
      );
      async.flushMicrotasks();

      expect(h.opened, ['https://one/sd.m3u8']);
    });
  });

  test('a stall moves on to the next link (REV-145)', () {
    fakeAsync((async) {
      final h = _Harness();
      addTearDown(h.dispose);
      unawaited(h.coordinator.changeChannel(_channel()));
      async.flushMicrotasks();

      h.buffering.add(true);
      async.elapse(const Duration(seconds: 16));

      expect(h.opened, ['https://one/a.m3u8', 'https://one/b.m3u8']);
    });
  });

  test('30 s of playback resets the failed rounds', () {
    fakeAsync((async) {
      final h = _Harness();
      addTearDown(h.dispose);
      unawaited(h.coordinator.changeChannel(_channel()));
      async.flushMicrotasks();

      h.failRound(async);
      async.elapse(const Duration(seconds: 2));
      h.position.add(const Duration(seconds: 100));
      h.position.add(const Duration(seconds: 131));
      async.flushMicrotasks();

      // Two more rounds would have been the third and given up.
      h.failRound(async);
      async.elapse(const Duration(seconds: 2));
      h.failRound(async);
      async.elapse(const Duration(seconds: 4));

      expect(h.state?.error, isNull);
    });
  });

  group('picture size', () {
    test('the sizes and the size on screen reach the state', () {
      fakeAsync((async) {
        final h = _Harness();
        addTearDown(h.dispose);
        unawaited(h.coordinator.changeChannel(_channel()));
        async.flushMicrotasks();

        h.sayRaiSizes(async);
        h.height.add(1080);
        async.flushMicrotasks();

        final sizes = h.state!.live.pictureSizes;
        expect(sizes.heights, [1080, 720, 432]);
        expect(sizes.picked, isNull);
        expect(sizes.playing, 1080);
      });
    });

    test('a stall changes source, never the size', () {
      fakeAsync((async) {
        final h = _Harness();
        addTearDown(h.dispose);
        unawaited(h.coordinator.changeChannel(_channel()));
        async.flushMicrotasks();
        h.sayRaiSizes(async);

        h.buffering.add(true);
        async.elapse(const Duration(seconds: 16));

        expect(h.opened, ['https://one/a.m3u8', 'https://one/b.m3u8']);
        expect(h.videoTracks, isNot(contains('3')));
        expect(h.suggestions, 0);
      });
    });

    test('three pauses within two minutes suggest a lower size, '
        'and the stream plays on', () {
      fakeAsync((async) {
        final h = _Harness();
        addTearDown(h.dispose);
        unawaited(h.coordinator.changeChannel(_channel()));
        async.flushMicrotasks();
        h.sayRaiSizes(async);
        h.playSettled(async);

        h.pause(async);
        h.pause(async);
        expect(h.suggestions, 0);

        h.pause(async);

        expect(h.suggestions, 1);
        expect(h.state?.notification, 'Try a lower quality');
        expect(h.opened, hasLength(1));
        expect(h.state?.live.pictureSizes.picked, isNull);
      });
    });

    test('the suggestion shows once per channel', () {
      fakeAsync((async) {
        final h = _Harness();
        addTearDown(h.dispose);
        unawaited(h.coordinator.changeChannel(_channel()));
        async.flushMicrotasks();
        h.sayRaiSizes(async);
        h.playSettled(async);
        for (var i = 0; i < 6; i++) {
          h.pause(async);
        }
        expect(h.suggestions, 1);

        unawaited(h.coordinator.changeChannel(_channel()));
        async.flushMicrotasks();
        expect(h.state?.notification, isNull);
        h.sayRaiSizes(async);
        h.playSettled(async);
        for (var i = 0; i < 3; i++) {
          h.pause(async);
        }

        expect(h.suggestions, 2);
      });
    });

    test('the loading after a seek is not a pause', () {
      fakeAsync((async) {
        final h = _Harness();
        addTearDown(h.dispose);
        unawaited(h.coordinator.changeChannel(_channel()));
        async.flushMicrotasks();
        h.sayRaiSizes(async);
        h.playSettled(async);

        for (var i = 0; i < 3; i++) {
          h.coordinator.onSeek();
          h.pause(async);
        }
        expect(h.suggestions, 0);

        // Once it has played a while, pauses count again.
        async.elapse(const Duration(seconds: 6));
        for (var i = 0; i < 3; i++) {
          h.pause(async);
        }
        expect(h.suggestions, 1);
        expect(h.opened, hasLength(1));
      });
    });

    test('the loading after an open and pauses far apart suggest nothing', () {
      fakeAsync((async) {
        final h = _Harness();
        addTearDown(h.dispose);
        unawaited(h.coordinator.changeChannel(_channel()));
        async.flushMicrotasks();
        h.sayRaiSizes(async);

        h.playSettled(async);
        h.pause(async);
        async.elapse(const Duration(minutes: 2));
        h.pause(async);
        async.elapse(const Duration(minutes: 2));
        h.pause(async);

        expect(h.suggestions, 0);
      });
    });

    test('no suggestion on the smallest size', () {
      fakeAsync((async) {
        final h = _Harness();
        addTearDown(h.dispose);
        unawaited(h.coordinator.changeChannel(_channel()));
        async.flushMicrotasks();
        h.sayRaiSizes(async);
        h.coordinator.pickPictureSize(432);
        async.flushMicrotasks();
        h.playSettled(async);

        for (var i = 0; i < 3; i++) {
          h.pause(async);
        }

        expect(h.suggestions, 0);
      });
    });

    test('a picked size reopens at it and never changes by itself', () {
      fakeAsync((async) {
        final h = _Harness();
        addTearDown(h.dispose);
        unawaited(h.coordinator.changeChannel(_channel()));
        async.flushMicrotasks();
        h.sayRaiSizes(async);

        h.coordinator.pickPictureSize(432);
        async.flushMicrotasks();
        expect(h.videoTracks, ['auto', '5']);
        expect(h.state?.live.pictureSizes.picked, 432);
        expect(h.state?.isResolving, isFalse);

        // Picking it again does nothing.
        h.coordinator.pickPictureSize(432);
        async.flushMicrotasks();
        expect(h.opened, hasLength(2));

        h.buffering.add(true);
        async.elapse(const Duration(seconds: 16));
        expect(h.opened.last, 'https://one/b.m3u8');
      });
    });

    test('picking the size already playing reopens nothing', () {
      fakeAsync((async) {
        final h = _Harness();
        addTearDown(h.dispose);
        unawaited(h.coordinator.changeChannel(_channel()));
        async.flushMicrotasks();
        h.sayRaiSizes(async);

        h.coordinator.pickPictureSize(1080);
        async.flushMicrotasks();

        expect(h.opened, hasLength(1));
        expect(h.state?.live.pictureSizes.picked, 1080);
      });
    });

    test('another channel starts on the biggest', () {
      fakeAsync((async) {
        final h = _Harness();
        addTearDown(h.dispose);
        unawaited(h.coordinator.changeChannel(_channel()));
        async.flushMicrotasks();
        h.sayRaiSizes(async);
        h.coordinator.pickPictureSize(432);
        async.flushMicrotasks();

        unawaited(h.coordinator.changeChannel(_channel()));
        async.flushMicrotasks();

        expect(h.videoTracks.last, 'auto');
        expect(h.state?.live.pictureSizes.picked, isNull);
        expect(h.state?.live.pictureSizes.heights, isEmpty);
      });
    });
  });
}
