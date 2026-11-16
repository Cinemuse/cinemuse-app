import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/custom_video_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mocktail/mocktail.dart';

import 'made_up_tmdb.dart';

class _MockPlayer extends Mock implements Player {}

class _MockPlayerStream extends Mock implements PlayerStream {}

class _MockPlayerState extends Mock implements PlayerState {}

class _MockVideoController extends Mock implements VideoController {}

class _FakeVideoState extends Fake implements VideoState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'FakeVideoState';
}

/// A player that does nothing: the controls only ask it to act.
class _IdlePlayerController extends Notifier<AsyncValue<CinemaPlayerState>>
    implements PlayerController {
  @override
  AsyncValue<CinemaPlayerState> build() => const AsyncValue.loading();

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The player for [MadeUpPlayerControls].
Override madeUpPlayerOverride() =>
    playerControllerProvider.overrideWith2((_) => _IdlePlayerController());

/// The video engine can't run in a test: one playing 40 minutes into a
/// 2 h 22 min film, paused, so the controls stay on screen.
VideoController _pausedVideo() {
  final player = _MockPlayer();
  final stream = _MockPlayerStream();
  final state = _MockPlayerState();
  when(() => player.stream).thenReturn(stream);
  when(() => player.state).thenReturn(state);
  when(() => stream.playing).thenAnswer((_) => const Stream.empty());
  when(() => stream.buffering).thenAnswer((_) => const Stream.empty());
  when(() => stream.volume).thenAnswer((_) => const Stream.empty());
  when(() => stream.position).thenAnswer((_) => const Stream.empty());
  when(() => state.playing).thenReturn(false);
  when(() => state.buffering).thenReturn(false);
  when(() => state.volume).thenReturn(100.0);
  when(() => state.position).thenReturn(const Duration(minutes: 40));
  when(() => state.duration).thenReturn(const Duration(minutes: 142));
  when(() => state.track).thenReturn(const Track());
  when(() => state.tracks).thenReturn(const Tracks());
  final controller = _MockVideoController();
  when(() => controller.player).thenReturn(player);
  return controller;
}

final _channel = Channel(
  lcn: 5,
  name: 'Canale 5',
  logo: '',
  epgId: 'ch4',
  links: [
    StreamLink(
      url: 'https://made-up.invalid/5.m3u8',
      quality: StreamQuality.hd,
    ),
  ],
);

/// The player's controls over a film, or over a live channel.
class MadeUpPlayerControls extends StatelessWidget {
  final bool isLive;

  const MadeUpPlayerControls({super.key, required this.isLive});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomVideoControls(
        videoState: _FakeVideoState(),
        playerState: CinemaPlayerState(
          controller: _pausedVideo(),
          availableStreams: const [],
          currentStream: null,
          title: isLive ? _channel.name : filmTitle,
          isLive: isLive,
        ),
        params: isLive
            ? PlayerParams(_channel.uniqueId, 'live')
            : const PlayerParams('$filmId', 'movie'),
        channel: isLive ? _channel : null,
        isLive: isLive,
        onSettingsPressed: (_) async {},
        onBackPressed: () {},
      ),
    );
  }
}
