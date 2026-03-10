import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'dart:async';
import 'dart:ui';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/video_top_bar.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/video_bottom_bar.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/next_episode_overlay.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/cast_device_selector.dart';
import 'package:cinemuse_app/core/presentation/widgets/buffering_indicator.dart';
import 'package:cinemuse_app/core/presentation/widgets/play_pause_overlay.dart';

class CustomVideoControls extends ConsumerStatefulWidget {
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
  ConsumerState<CustomVideoControls> createState() => _CustomVideoControlsState();
}

class _CustomVideoControlsState extends ConsumerState<CustomVideoControls> {
  bool _visible = true;
  Timer? _hideTimer;
  bool _dragging = false;
  double _lastVolume = 100.0;
  Timer? _skipTimer;
  LogicalKeyboardKey? _lastSkipKey;
  int _skipCount = 0;
  Duration? _virtualPosition;
  Timer? _clearVirtualPositionTimer;

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
    final notifier = ref.read(playerControllerProvider(widget.params).notifier);
    final player = widget.playerState.controller.player;
    
    if (player.state.playing) {
      notifier.pause();
    } else {
      notifier.play();
    }
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
      if (_lastSkipKey == key) return;

      if (key == LogicalKeyboardKey.space) {
        _togglePlayPause();
      } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
        _lastSkipKey = key;
        _skipCount = 0;
        
        _clearVirtualPositionTimer?.cancel();
        if (_virtualPosition == null) {
          setState(() {
            _virtualPosition = player.state.position;
          });
        }

        _performVirtualSkip(key == LogicalKeyboardKey.arrowRight, step: 10);
        
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
        
        if (_virtualPosition != null) {
          ref.read(playerControllerProvider(widget.params).notifier).seek(_virtualPosition!);
          
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
    
    _skipTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
       _performVirtualSkip(forward, step: 5);
       _skipCount++;
       
       if (_skipCount > 40) {
          _performVirtualSkip(forward, step: 10); 
       }
    });
  }

  void _performRealSkip(bool forward) {
    final player = widget.playerState.controller.player;
    final pos = player.state.position;
    final duration = player.state.duration;
    final target = Duration(seconds: (pos.inSeconds + (forward ? 10 : -10)).clamp(0, duration.inSeconds));
    ref.read(playerControllerProvider(widget.params).notifier).seek(target);
    _onHover();
  }

  Future<void> _handleCastPressed(BuildContext context) async {
    if (widget.playerState.isCasting) {
      await ref.read(playerControllerProvider(widget.params).notifier).stopCasting();
      return;
    }

    final device = await CastDeviceSelector.show(context);
    if (device != null) {
      await ref.read(playerControllerProvider(widget.params).notifier).startCasting(device);
    }
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
              AnimatedOpacity(
                opacity: _visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: VideoTopBar(
                        playerState: widget.playerState,
                        params: widget.params,
                        onSettingsPressed: widget.onSettingsPressed,
                        onCastPressed: () => _handleCastPressed(context),
                        onBackPressed: () => Navigator.of(context).pop(),
                      ),
                    ),

                    // Buffering / play-pause center overlay
                    BufferingIndicator(player: player),
                    PlayPauseOverlay(player: player, visible: _visible),

                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: VideoBottomBar(
                        playerState: widget.playerState,
                        virtualPosition: _virtualPosition,
                        dragging: _dragging,
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
                          ref.read(playerControllerProvider(widget.params).notifier).seek(target);
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
                        onTogglePlayPause: _togglePlayPause,
                        onSkip: _performRealSkip,
                        onToggleMute: _toggleMute,
                        isFullscreen: _isFullscreenSafe(),
                        onToggleFullscreen: _toggleFullscreen,
                        onNextEpisode: widget.onNextEpisode,
                      ),
                    ),
                  ],
                ),
              ),

              if (widget.onNextEpisode != null)
                NextEpisodeOverlay(
                  playerState: widget.playerState,
                  onNextEpisode: widget.onNextEpisode!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
