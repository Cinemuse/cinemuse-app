import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'dart:async';
import 'dart:ui';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';

class CustomVideoControls extends StatefulWidget {
  final VideoState videoState;
  final CinemaPlayerState playerState;
  final PlayerParams params;
  final VoidCallback onSettingsPressed;
  final VoidCallback? onNextEpisode;

  const CustomVideoControls({
    super.key,
    required this.videoState,
    required this.playerState,
    required this.params,
    required this.onSettingsPressed,
    this.onNextEpisode,
  });

  @override
  State<CustomVideoControls> createState() => _CustomVideoControlsState();
}

class _CustomVideoControlsState extends State<CustomVideoControls> {
  bool _visible = true;
  Timer? _hideTimer;
  bool _dragging = false;
  double _lastVolume = 100.0;
  Timer? _skipTimer;
  LogicalKeyboardKey? _lastSkipKey;
  int _skipCount = 0;
  Duration? _virtualPosition;
  Timer? _clearVirtualPositionTimer;
  bool _showVolumeSlider = false;
  
  // Seekbar Hover State
  double? _hoverX;
  Duration? _hoverDuration;
  bool _isHoveringSeekbar = false;
  bool _isNextButtonHovered = false;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _skipTimer?.cancel();
    _clearVirtualPositionTimer?.cancel();
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

  void _toggleMute() {
    final player = widget.playerState.controller.player;
    final currentVolume = player.state.volume;
    
    if (currentVolume > 0) {
      _lastVolume = currentVolume;
      player.setVolume(0);
    } else {
      player.setVolume(_lastVolume > 0 ? _lastVolume : 100);
    }
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

  void _toggleFullscreen() {
    if (_isFullscreenSafe()) {
      widget.videoState.exitFullscreen();
    } else {
      widget.videoState.enterFullscreen();
    }
    setState(() {});
  }

  void _handleKeyEvent(KeyEvent event) {
    final player = widget.playerState.controller.player;
    final key = event.logicalKey;

    if (event is KeyDownEvent) {
      // Avoid system repeated keys
      if (_lastSkipKey == key) return;

      if (key == LogicalKeyboardKey.space) {
        _togglePlayPause();
      } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
        _lastSkipKey = key;
        _skipCount = 0;
        
        // Accumulate on existing virtual position if recently active
        _clearVirtualPositionTimer?.cancel();
        if (_virtualPosition == null) {
          setState(() {
            _virtualPosition = player.state.position;
          });
        }

        // Initial skip (virtual)
        _performVirtualSkip(key == LogicalKeyboardKey.arrowRight, step: 10);
        
        // Start continuous skip timer after a slightly longer delay for better control
        _skipTimer?.cancel();
        _skipTimer = Timer(const Duration(milliseconds: 400), () {
          _startContinuousVirtualSkip(key == LogicalKeyboardKey.arrowRight);
        });
      } else if (key == LogicalKeyboardKey.arrowUp) {
        final vol = player.state.volume;
        player.setVolume((vol + 10.0).clamp(0.0, 100.0));
        _onHover();
      } else if (key == LogicalKeyboardKey.arrowDown) {
        final vol = player.state.volume;
        player.setVolume((vol - 10.0).clamp(0.0, 100.0));
        _onHover();
      } else if (key == LogicalKeyboardKey.keyM) {
        _toggleMute();
      } else if (key == LogicalKeyboardKey.keyF) {
        _toggleFullscreen();
      } else if (key == LogicalKeyboardKey.escape) {
        Navigator.of(context).pop();
      } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
        // Trigger Next Episode if in "Finished" state and overlay is visible
        final pos = player.state.position.inSeconds;
        final dur = player.state.duration.inSeconds;
        final isFinished = dur > 0 && (dur - pos < 180 || (pos / dur) > 0.95);
        
        if (isFinished && widget.onNextEpisode != null) {
          widget.onNextEpisode!();
        }
      }
    } else if (event is KeyUpEvent) {
      if (key == _lastSkipKey) {
        _skipTimer?.cancel();
        _lastSkipKey = null;
        
        // Perform the final REAL seek on release
        if (_virtualPosition != null) {
          player.seek(_virtualPosition!);
          
          // Defer clearing virtual position to allow rapid "spam" accumulation
          _clearVirtualPositionTimer?.cancel();
          _clearVirtualPositionTimer = Timer(const Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() {
                _virtualPosition = null;
              });
            }
          });
        }
      }
    }
  }

  void _performVirtualSkip(bool forward, {int step = 5}) {
    final duration = widget.playerState.controller.player.state.duration;
    if (_virtualPosition == null) return;

    setState(() {
      final offset = forward ? step : -step;
      _virtualPosition = Duration(
        seconds: (_virtualPosition!.inSeconds + offset).clamp(0, duration.inSeconds),
      );
    });
    _onHover();
  }

  void _startContinuousVirtualSkip(bool forward) {
    _onHover();
    _skipTimer?.cancel();
    
    // Very fast UI updates (every 50ms) with small steps (5s)
    // This gives a super smooth feeling without hitting the network
    _skipTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
       _performVirtualSkip(forward, step: 5);
       _skipCount++;
       
       // Accelerate step size after a longer period (~2 seconds of holding)
       if (_skipCount > 40) {
          // Accelerate step size to 15s total (5 + 10)
          _performVirtualSkip(forward, step: 10); 
       }
    });
  }

  // Keep these for UI buttons (which still do real skips for now as they are single taps)
  void _performRealSkip(bool forward) {
    final player = widget.playerState.controller.player;
    final pos = player.state.position;
    final duration = player.state.duration;
    player.seek(Duration(seconds: (pos.inSeconds + (forward ? 10 : -10)).clamp(0, duration.inSeconds)));
    _onHover();
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.playerState.controller.player;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        _handleKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: MouseRegion(
        onHover: (_) => _onHover(),
        child: GestureDetector(
          onTap: () {
            if (_visible) {
              _togglePlayPause();
            } else {
              _onHover();
            }
          },
          onDoubleTap: _toggleFullscreen,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              // Main Controls Overlay (Animated Opacity)
              AnimatedOpacity(
                opacity: _visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Stack(
                  children: [
                    // Top Bar (Metadata & Header)
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.playerState.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (widget.params.type == 'tv' && widget.params.season != null && widget.params.episode != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'S${widget.params.season.toString().padLeft(2, '0')}E${widget.params.episode.toString().padLeft(2, '0')}${widget.params.episodeTitle != null ? ' - ${widget.params.episodeTitle}' : ''}',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
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

                    // Center (Buffering & Pause Indicator)
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
                              if (!isPlaying && _visible) {
                                return IgnorePointer(
                                  ignoring: true,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: const BoxDecoration(
                                      color: Colors.black45,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          );
                        },
                      ),
                    ),

                    // Bottom Bar (Seekbar & Controls)
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
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 3a. Seekbar
                            StreamBuilder<Duration>(
                              stream: player.stream.position,
                              builder: (context, snapshot) {
                                final position = _virtualPosition ?? snapshot.data ?? Duration.zero;
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
                                                    activeTrackColor: Colors.white,
                                                    inactiveTrackColor: Colors.white24,
                                                    thumbColor: Colors.white,
                                                  ),
                                                  child: Slider(
                                                    value: position.inSeconds.toDouble().clamp(0, duration.inSeconds.toDouble()),
                                                    min: 0,
                                                    max: duration.inSeconds.toDouble(),
                                                    onChangeStart: (value) {
                                                      setState(() {
                                                        _dragging = true;
                                                        _virtualPosition = Duration(seconds: value.toInt());
                                                      });
                                                      _hideTimer?.cancel();
                                                      _clearVirtualPositionTimer?.cancel();
                                                    },
                                                    onChangeEnd: (value) {
                                                      final target = Duration(seconds: value.toInt());
                                                      player.seek(target);
                                                      setState(() {
                                                        _dragging = false;
                                                        _virtualPosition = target;
                                                      });
                                                      _startHideTimer();
                                                      _clearVirtualPositionTimer?.cancel();
                                                      _clearVirtualPositionTimer = Timer(const Duration(milliseconds: 500), () {
                                                        if (mounted) setState(() => _virtualPosition = null);
                                                      });
                                                    },
                                                    onChanged: (value) => setState(() => _virtualPosition = Duration(seconds: value.toInt())),
                                                  ),
                                                ),
                                                if (_isHoveringSeekbar && _hoverX != null && _hoverDuration != null)
                                                  Positioned(
                                                    left: (_hoverX! - 35).clamp(0, constraints.maxWidth - 70),
                                                    top: -35,
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black.withOpacity(0.8),
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(color: Colors.white24, width: 0.5),
                                                      ),
                                                      child: Text(
                                                        _formatDuration(_hoverDuration!),
                                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
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
                                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace'),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                );
                              },
                            ),
                            // 3b. Bottom Controls Row
                            Row(
                              children: [
                                StreamBuilder<bool>(
                                  stream: player.stream.playing,
                                  initialData: player.state.playing,
                                  builder: (context, snapshot) {
                                    final isPlaying = snapshot.data ?? player.state.playing;
                                    return IconButton(
                                      icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 32),
                                      onPressed: _togglePlayPause,
                                    );
                                  },
                                ),
                                IconButton(icon: const Icon(Icons.replay_10_rounded, color: Colors.white), onPressed: () => _performRealSkip(false)),
                                IconButton(icon: const Icon(Icons.forward_10_rounded, color: Colors.white), onPressed: () => _performRealSkip(true)),
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
                                          return IconButton(icon: Icon(iconData, color: Colors.white, size: 24), onPressed: _toggleMute, padding: const EdgeInsets.all(8), constraints: const BoxConstraints(), splashRadius: 20);
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
                                                      onChanged: (v) { player.setVolume(v); _onHover(); },
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
                                  icon: Icon(_isFullscreenSafe() ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white),
                                  onPressed: _toggleFullscreen,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // End-of-Episode Skip Overlay (Outside AnimatedOpacity)
              if (widget.onNextEpisode != null)
                StreamBuilder<Duration>(
                  stream: player.stream.position,
                  builder: (context, snapshot) {
                    final pos = snapshot.data?.inSeconds ?? player.state.position.inSeconds;
                    final dur = player.state.duration.inSeconds;
                    if (dur <= 0) return const SizedBox.shrink();
                    final isFinished = (dur - pos < 180) || (pos / dur > 0.95);

                    return AnimatedPositioned(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutQuart,
                      bottom: isFinished ? 100 : -100,
                      right: 32,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        onEnter: (_) => setState(() => _isNextButtonHovered = true),
                        onExit: (_) => setState(() => _isNextButtonHovered = false),
                        child: GestureDetector(
                          onTap: widget.onNextEpisode,
                          child: AnimatedScale(
                            scale: _isNextButtonHovered ? 1.05 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: _isNextButtonHovered ? 16 : 12,
                                  sigmaY: _isNextButtonHovered ? 16 : 12,
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(_isNextButtonHovered ? 0.95 : 0.85),
                                        Colors.white.withOpacity(_isNextButtonHovered ? 0.85 : 0.65),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(_isNextButtonHovered ? 0.4 : 0.2),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(_isNextButtonHovered ? 0.4 : 0.3),
                                        blurRadius: _isNextButtonHovered ? 30 : 25,
                                        offset: Offset(0, _isNextButtonHovered ? 12 : 10),
                                        spreadRadius: -5,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Next Episode'.toUpperCase(),
                                        style: TextStyle(
                                          color: Colors.black.withOpacity(0.85),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        color: Colors.black.withOpacity(0.85),
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
