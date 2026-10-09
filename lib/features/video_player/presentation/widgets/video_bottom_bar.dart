import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/application/display_mode_provider.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/presentation/helpers/playback_control_actions.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/live_tv_seekbar.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/video_playback_controls.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/vod_seekbar.dart';

/// Bottom bar overlay containing the timeline seekbar (Live TV or VOD)
/// and playback controls.
class VideoBottomBar extends ConsumerWidget {
  final CinemaPlayerState playerState;
  final Duration? virtualPosition;
  final bool dragging;
  final ValueChanged<double> onChangeStart;
  final ValueChanged<double> onChangeEnd;
  final ValueChanged<double> onChanged;
  final PlaybackControlActions actions;

  const VideoBottomBar({
    super.key,
    required this.playerState,
    this.virtualPosition,
    required this.dragging,
    required this.onChangeStart,
    required this.onChangeEnd,
    required this.onChanged,
    required this.actions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = playerState.controller.player;
    final isBigPicture = ref.watch(isBigPictureProvider);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            AppTheme.primary.withValues(alpha: 0.87),
            AppTheme.primary.withValues(alpha: 0),
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seekbar (VOD or Live TV)
          RepaintBoundary(
            child: StreamBuilder<Duration>(
              stream: player.stream.position,
              builder: (context, snapshot) {
                final rawDuration = player.state.duration;
                final position =
                    virtualPosition ?? snapshot.data ?? Duration.zero;

                if (actions.isLive) {
                  return LiveTvSeekbar(
                    player: player,
                    rawDuration: rawDuration,
                    position: position,
                    dragging: dragging,
                    isBigPicture: isBigPicture,
                    seekbarFocusNode: actions.seekbarFocusNode,
                    playPauseFocusNode: actions.playPauseFocusNode,
                    onChangeStart: onChangeStart,
                    onChanged: onChanged,
                    onChangeEnd: onChangeEnd,
                    onInteraction: actions.onResetHideTimer,
                  );
                }

                return VodSeekbar(
                  player: player,
                  position: position,
                  duration: rawDuration,
                  isBigPicture: isBigPicture,
                  seekbarFocusNode: actions.seekbarFocusNode,
                  playPauseFocusNode: actions.playPauseFocusNode,
                  onChangeStart: onChangeStart,
                  onChanged: onChanged,
                  onChangeEnd: onChangeEnd,
                  onInteraction: actions.onResetHideTimer,
                );
              },
            ),
          ),

          // Bottom Controls Row
          VideoPlaybackControls(playerState: playerState, actions: actions),
        ],
      ),
    );
  }
}
