import 'package:flutter/material.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';

class VideoPlaybackControls extends StatefulWidget {
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
  State<VideoPlaybackControls> createState() => _VideoPlaybackControlsState();
}

class _VideoPlaybackControlsState extends State<VideoPlaybackControls> {
  bool _showVolumeSlider = false;

  @override
  Widget build(BuildContext context) {
    final player = widget.playerState.controller.player;

    return Row(
      children: [
        StreamBuilder<bool>(
          stream: player.stream.playing,
          initialData: player.state.playing,
          builder: (context, snapshot) {
            final isPlaying = snapshot.data ?? player.state.playing;
            return IconButton(
              icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 32),
              onPressed: widget.onTogglePlayPause,
            );
          },
        ),
        IconButton(icon: const Icon(Icons.replay_10_rounded, color: Colors.white), onPressed: () => widget.onSkip(false)),
        IconButton(icon: const Icon(Icons.forward_10_rounded, color: Colors.white), onPressed: () => widget.onSkip(true)),
        const SizedBox(width: 4),
        MouseRegion(
          onEnter: (_) => setState(() => _showVolumeSlider = true),
          onExit: (_) => setState(() => _showVolumeSlider = false),
          child: Row(
            children: [
              StreamBuilder<double>(
                stream: player.stream.volume,
                initialData: player.state.volume,
                builder: (context, snapshot) {
                  final volume = snapshot.data ?? player.state.volume;
                  IconData iconData = Icons.volume_up_rounded;
                  if (volume == 0) iconData = Icons.volume_off_rounded;
                  else if (volume < 50) iconData = Icons.volume_down_rounded;
                  return IconButton(icon: Icon(iconData, color: Colors.white, size: 24), onPressed: widget.onToggleMute, padding: const EdgeInsets.all(8), constraints: const BoxConstraints(), splashRadius: 20);
                },
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: _showVolumeSlider ? 100 : 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _showVolumeSlider ? 1 : 0,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: SizedBox(
                      width: 100,
                      child: StreamBuilder<double>(
                        stream: player.stream.volume,
                        initialData: player.state.volume,
                        builder: (context, snapshot) {
                          final volume = snapshot.data ?? player.state.volume;
                          return SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: Colors.white,
                            ),
                            child: Slider(
                              value: volume.clamp(0.0, 100.0),
                              min: 0.0,
                              max: 100.0,
                              onChanged: (v) { player.setVolume(v); },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (widget.onNextEpisode != null)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: IconButton(
              icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 28),
              onPressed: widget.onNextEpisode,
              tooltip: 'Next Episode',
            ),
          ),
        IconButton(
          icon: Icon(widget.isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white),
          onPressed: widget.onToggleFullscreen,
        ),
      ],
    );
  }
}
