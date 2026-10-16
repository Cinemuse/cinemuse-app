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

class _MockPlayerStream extends Mock implements PlayerStream {}

class _MockVideoController extends Mock implements VideoController {}

/// A coordinator on a mocked player; [opened] lists every URL it opens.
class _Harness {
  final player = _MockPlayer();
  final buffering = StreamController<bool>.broadcast();
  final position = StreamController<Duration>.broadcast();
  final opened = <String>[];
  CinemaPlayerState? state;
  late final LiveTvPlaybackCoordinator coordinator;

  _Harness() {
    final stream = _MockPlayerStream();
    when(() => player.stream).thenReturn(stream);
    when(() => stream.buffering).thenAnswer((_) => buffering.stream);
    when(() => stream.position).thenAnswer((_) => position.stream);
    when(() => stream.duration).thenAnswer((_) => const Stream.empty());
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
    );
  }

  void dispose() {
    coordinator.dispose();
    unawaited(buffering.close());
    unawaited(position.close());
  }

  /// Both links fail once: one full round.
  void failRound(FakeAsync async) {
    unawaited(coordinator.handleFailover('404', isConnectionError: true));
    async.flushMicrotasks();
    unawaited(coordinator.handleFailover('404', isConnectionError: true));
    async.flushMicrotasks();
  }
}

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
}
