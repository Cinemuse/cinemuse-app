import 'package:flutter/material.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/video_playback_controls.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';

class VideoBottomBar extends StatefulWidget {
  final CinemaPlayerState playerState;
  final Duration? virtualPosition;
  final bool dragging;
  final Function(double) onChangeStart;
  final Function(double) onChangeEnd;
  final Function(double) onChanged;
  final VoidCallback onTogglePlayPause;
  final Function(bool) onSkip;
  final VoidCallback onToggleMute;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;
  final VoidCallback? onNextEpisode;

  const VideoBottomBar({
    super.key,
    required this.playerState,
    this.virtualPosition,
    required this.dragging,
    required this.onChangeStart,
    required this.onChangeEnd,
    required this.onChanged,
    required this.onTogglePlayPause,
    required this.onSkip,
    required this.onToggleMute,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    this.onNextEpisode,
  });

  @override
  State<VideoBottomBar> createState() => _VideoBottomBarState();
}

class _VideoBottomBarState extends State<VideoBottomBar> {
  double? _hoverX;
  Duration? _hoverDuration;
  bool _isHoveringSeekbar = false;

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
    }
    return '${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.playerState.controller.player;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [AppTheme.primary.withOpacity(0.87), Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seekbar
          StreamBuilder<Duration>(
            stream: player.stream.position,
            builder: (context, snapshot) {
              final position = widget.virtualPosition ?? snapshot.data ?? Duration.zero;
              final duration = player.state.duration;
              return Row(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return MouseRegion(
                          onHover: (event) {
                            setState(() {
                              _hoverX = event.localPosition.dx;
                              _isHoveringSeekbar = true;
                              final percent = (_hoverX! / constraints.maxWidth).clamp(0.0, 1.0);
                              _hoverDuration = Duration(seconds: (duration.inSeconds * percent).toInt());
                            });
                          },
                          onExit: (_) {
                            setState(() {
                              _isHoveringSeekbar = false;
                              _hoverX = null;
                              _hoverDuration = null;
                            });
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 2,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                  activeTrackColor: AppTheme.textWhite,
                                  inactiveTrackColor: AppTheme.textWhite.withOpacity(0.24),
                                  thumbColor: AppTheme.textWhite,
                                ),
                                child: Slider(
                                  value: position.inSeconds.toDouble().clamp(0, duration.inSeconds.toDouble()),
                                  min: 0,
                                  max: duration.inSeconds.toDouble(),
                                  onChangeStart: widget.onChangeStart,
                                  onChangeEnd: widget.onChangeEnd,
                                  onChanged: widget.onChanged,
                                ),
                              ),
                              if (_isHoveringSeekbar && _hoverX != null && _hoverDuration != null)
                                Positioned(
                                  left: (_hoverX! - 35).clamp(0, constraints.maxWidth - 70),
                                  top: -35,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppTheme.textWhite.withOpacity(0.24), width: 0.5),
                                    ),
                                    child: Text(
                                      _formatDuration(_hoverDuration!),
                                      style: const TextStyle(color: AppTheme.textWhite, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_formatDuration(position)} / ${_formatDuration(duration)}',
                    style: TextStyle(color: AppTheme.textWhite.withOpacity(0.7), fontSize: 13, fontFamily: 'monospace'),
                  ),
                  const SizedBox(width: 8),
                ],
              );
            },
          ),
          // Bottom Controls Row
          VideoPlaybackControls(
            playerState: widget.playerState,
            onTogglePlayPause: widget.onTogglePlayPause,
            onSkip: widget.onSkip,
            onToggleMute: widget.onToggleMute,
            isFullscreen: widget.isFullscreen,
            onToggleFullscreen: widget.onToggleFullscreen,
            onNextEpisode: widget.onNextEpisode,
          ),
        ],
      ),
    );
  }
}
