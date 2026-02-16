import 'dart:async';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

class CustomVideoControls extends StatefulWidget {
  final VideoState videoState;
  final CinemaPlayerState playerState;
  final PlayerParams params;
  final VoidCallback onSettingsPressed;

  const CustomVideoControls({
    super.key,
    required this.videoState,
    required this.playerState,
    required this.params,
    required this.onSettingsPressed,
  });

  @override
  State<CustomVideoControls> createState() => _CustomVideoControlsState();
}

class _CustomVideoControlsState extends State<CustomVideoControls> {
  bool _visible = true;
  Timer? _hideTimer;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_dragging && widget.playerState.controller.player.state.playing) {
        setState(() {
          _visible = false;
        });
      }
    });
  }

  void _onHover() {
    if (!_visible) {
      setState(() {
        _visible = true;
      });
    }
    _startHideTimer();
  }

  void _togglePlayPause() {
    final player = widget.playerState.controller.player;
    player.playOrPause();
    _onHover();
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
    }
    return '${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  bool _isFullscreenSafe() {
    try {
      if (!mounted) return false;
      return widget.videoState.isFullscreen();
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.playerState.controller.player;

    return MouseRegion(
      onHover: (_) => _onHover(),
      child: GestureDetector(
        onTap: () {
            if (_visible) {
               _togglePlayPause();
            } else {
               _onHover();
            }
        },
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // Buffering Indicator moved to Center Widget logic
            
            // Controls Overlay
            AnimatedOpacity(
              opacity: _visible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Stack(
                children: [
                   // Top Bar
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              widget.playerState.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings, color: Colors.white),
                            onPressed: widget.onSettingsPressed,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Center Play/Pause & Buffering
                  Center(
                    child: StreamBuilder<bool>(
                      stream: player.stream.buffering,
                      initialData: player.state.buffering,
                      builder: (context, bufferingSnapshot) {
                        final isBuffering = bufferingSnapshot.data == true;
                        
                        if (isBuffering) {
                          return const CircularProgressIndicator(color: AppTheme.accent);
                        }

                        return StreamBuilder<bool>(
                          stream: player.stream.playing,
                          initialData: player.state.playing,
                          builder: (context, playingSnapshot) {
                            final isPlaying = playingSnapshot.data ?? player.state.playing;
                            
                            // Only show Play arrow when PAUSED
                            if (!isPlaying && _visible) {
                               return IgnorePointer(
                                 ignoring: true, 
                                 child: Container(
                                   padding: const EdgeInsets.all(16),
                                   decoration: BoxDecoration(
                                     color: Colors.black45,
                                     shape: BoxShape.circle,
                                   ),
                                   child: const Icon(
                                     Icons.play_arrow,
                                     color: Colors.white,
                                     size: 48,
                                   ),
                                 ),
                               );
                            }
                            return const SizedBox.shrink();
                          },
                        );
                      },
                    ),
                  ),

                  // Bottom Bar
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Seek Bar & Time
                          StreamBuilder<Duration>(
                            stream: player.stream.position,
                            builder: (context, snapshot) {
                              final position = snapshot.data ?? Duration.zero;
                              final duration = player.state.duration;
                              
                              return Row(
                                children: [
                                  Text(
                                    _formatDuration(position),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderThemeData(
                                        trackHeight: 4,
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                        activeTrackColor: AppTheme.accent,
                                        inactiveTrackColor: Colors.white24,
                                        thumbColor: AppTheme.accent,
                                      ),
                                      child: Slider(
                                        value: position.inSeconds.toDouble().clamp(0, duration.inSeconds.toDouble()),
                                        min: 0,
                                        max: duration.inSeconds.toDouble(),
                                        onChangeStart: (_) {
                                            _dragging = true;
                                            _hideTimer?.cancel();
                                        },
                                        onChangeEnd: (_) {
                                            _dragging = false;
                                            _startHideTimer();
                                        },
                                        onChanged: (value) {
                                          player.seek(Duration(seconds: value.toInt()));
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _formatDuration(duration),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  const SizedBox(width: 12),
                                  // Fullscreen Button
                                  IconButton(
                                    icon: Icon(
                                      _isFullscreenSafe() ? Icons.fullscreen_exit : Icons.fullscreen,
                                      color: Colors.white,
                                    ),
                                    onPressed: () {
                                      if (_isFullscreenSafe()) {
                                        widget.videoState.exitFullscreen();
                                      } else {
                                        widget.videoState.enterFullscreen();
                                      }
                                      setState(() {}); // Rebuild to update icon
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
