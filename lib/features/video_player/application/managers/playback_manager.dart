import 'dart:async';
import 'package:cinemuse_app/features/video_player/application/managers/base_manager.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/cast_handler.dart';
import 'package:cast/cast.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/streaming/models/resolved_stream.dart';

/// Manager for player playback controls: play, pause, seek, and cast management.
class PlaybackManager extends BaseManager {
  final CastHandler castHandler;
  final bool Function() isCasting;

  PlaybackManager({
    required super.ref,
    required super.player,
    required this.castHandler,
    required this.isCasting,
  });

  Future<void> play() async {
    if (isCasting()) {
      castHandler.play();
    } else {
      player.play();
    }
  }

  Future<void> pause() async {
    if (isCasting()) {
      castHandler.pause();
    } else {
      player.pause();
    }
  }

  Future<void> seek(Duration position) async {
    if (isCasting()) {
      castHandler.seek(position);
    } else {
      await player.seek(position);
    }
  }

  Future<void> stopCasting() async {
    await castHandler.stopCasting();
  }

  Future<void> startCasting(
    CastDevice device, 
    StreamCandidate candidate, 
    String title, 
    Duration currentPosition,
    Function(ResolvedStream) onStreamResolved, {
    int? season,
    int? episode,
    int? absoluteEpisode,
  }) async {
    await castHandler.startCasting(
      device, 
      candidate, 
      title, 
      currentPosition, 
      onStreamResolved,
      season: season,
      episode: episode,
      absoluteEpisode: absoluteEpisode,
    );
  }
}
