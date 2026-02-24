import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/core/presentation/widgets/volume_control.dart';
import 'package:cinemuse_app/core/presentation/widgets/fullscreen_button.dart';

/// Bottom-row playback controls for the VOD video player.
///
/// Uses shared [VolumeControl] and [FullscreenButton] widgets.
class VideoPlaybackControls extends StatelessWidget {
  final CinemaPlayerState playerState;
  final VoidCallback onTogglePlayPause;
  final Function(bool) onSkip;
  final VoidCallback onToggleMute;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;
  final VoidCallback? onNextEpisode;

  const VideoPlaybackControls({
    super.key,
    required this.playerState,
    required this.onTogglePlayPause,
    required this.onSkip,
    required this.onToggleMute,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    this.onNextEpisode,
  });

  @override
  Widget build(BuildContext context) {
    final player = playerState.controller.player;

    return Row(
      children: [
        // Play / Pause
        StreamBuilder<bool>(
          stream: player.stream.playing,
          initialData: player.state.playing,
          builder: (context, snapshot) {
            final isPlaying = snapshot.data ?? player.state.playing;
            return IconButton(
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32,
              ),
              onPressed: onTogglePlayPause,
            );
          },
        ),

        // Skip backward / forward
        IconButton(
          icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
          onPressed: () => onSkip(false),
        ),
        IconButton(
          icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
          onPressed: () => onSkip(true),
        ),

        const SizedBox(width: 4),

        // Volume — shared widget
        VolumeControl(player: player),

        const Spacer(),

        // Next episode
        if (onNextEpisode != null)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: IconButton(
              icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 28),
              onPressed: onNextEpisode,
              tooltip: 'Next Episode',
            ),
          ),

        // Fullscreen — shared widget
        FullscreenButton(
          isFullscreen: isFullscreen,
          onToggle: onToggleFullscreen,
        ),
      ],
    );
  }
}
