import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'dart:async';
import 'dart:io';
import 'package:window_manager/window_manager.dart';

import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/video_top_bar.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/video_bottom_bar.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/next_episode_overlay.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/cast_device_selector.dart';
import 'package:cinemuse_app/core/constants/playback_constants.dart';
import 'package:cinemuse_app/core/presentation/widgets/buffering_indicator.dart';
import 'package:cinemuse_app/core/presentation/widgets/play_pause_overlay.dart';
import 'package:cinemuse_app/core/presentation/widgets/seek_feedback_overlay.dart';

enum DragType { none, volume, brightness }

class CustomVideoControls extends ConsumerStatefulWidget {
  final VideoState videoState;
  final CinemaPlayerState playerState;
  final PlayerParams params;
  final VoidCallback onSettingsPressed;
  final VoidCallback onBackPressed;
  final ValueChanged<SliderOverlayType> onOverlayRequested;
  final VoidCallback? onNextEpisode;

  const CustomVideoControls({
    super.key,
    required this.videoState,
    required this.playerState,
    required this.params,
    required this.onSettingsPressed,
    required this.onBackPressed,
    required this.onOverlayRequested,
    this.onNextEpisode,
  });

  @override
  ConsumerState<CustomVideoControls> createState() =>
      _CustomVideoControlsState();
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
  bool _isFullScreen = false;

  DragType _currentDragType = DragType.none;
  double _brightnessLevel = 1.0; // 0.0 to 1.0
  Timer? _hideIndicatorTimer;
  double _dragIndicatorValue = 0.0;
  Offset? _doubleTapPosition;

  bool _showSeekIndicator = false;
  int _seekAmount = 0;
  Timer? _seekIndicatorTimer;

  /// Tracks whether the window was already maximized before we entered
  /// fullscreen, so we can restore the original state on exit.
  static bool _wasMaximizedBeforeFullscreen = false;
  static Rect? _previousBounds;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
    _initFullscreenState();
  }

  void _initFullscreenState() {
    if (mounted) setState(() => _isFullScreen = _isFullscreenSafe());
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _skipTimer?.cancel();
    _clearVirtualPositionTimer?.cancel();
    _hideIndicatorTimer?.cancel();
    _seekIndicatorTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted &&
          !_dragging &&
          _currentDragType == DragType.none &&
          widget.playerState.controller.player.state.playing) {
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

  Future<void> _toggleFullscreen() async {
    if (_isFullscreenSafe()) {
      debugPrint(
        "[Fullscreen Debug] Exiting fullscreen. wasMaximized: $_wasMaximizedBeforeFullscreen, prevBounds: $_previousBounds",
      );
      await widget.videoState.exitFullscreen();
      if (Platform.isWindows || Platform.isLinux) {
        if (!_wasMaximizedBeforeFullscreen) {
          await windowManager.unmaximize();
          if (_previousBounds != null) {
            await windowManager.setBounds(_previousBounds!);
          }
        } else {
          debugPrint("[Fullscreen Debug] Restoring maximized state");
          await windowManager.maximize();
        }
      }
      if (mounted) setState(() => _isFullScreen = false);
    } else {
      if (Platform.isWindows || Platform.isLinux) {
        _wasMaximizedBeforeFullscreen = await windowManager.isMaximized();
        debugPrint(
          "[Fullscreen Debug] Entering fullscreen. initiallyMaximized: $_wasMaximizedBeforeFullscreen",
        );
        if (!_wasMaximizedBeforeFullscreen) {
          _previousBounds = await windowManager.getBounds();
          debugPrint(
            "[Fullscreen Debug] Saved bounds: $_previousBounds. Maximizing to trick WM.",
          );
          await windowManager.maximize();
        }
      }
      await widget.videoState.enterFullscreen();
      if (mounted) setState(() => _isFullScreen = true);
    }
  }

  Future<void> _handleBack() async {
    if (_isFullscreenSafe()) {
      debugPrint(
        "[Fullscreen Debug] _handleBack: Exiting fullscreen. wasMaximized: $_wasMaximizedBeforeFullscreen, prevBounds: $_previousBounds",
      );
      await widget.videoState.exitFullscreen();
      if (Platform.isWindows || Platform.isLinux) {
        if (!_wasMaximizedBeforeFullscreen) {
          await windowManager.unmaximize();
          if (_previousBounds != null) {
            await windowManager.setBounds(_previousBounds!);
          }
        } else {
          debugPrint(
            "[Fullscreen Debug] _handleBack: Restoring maximized state",
          );
          await windowManager.maximize();
        }
      }
      _isFullScreen = false;
    }
    if (mounted) widget.onBackPressed();
  }

  void _handleKeyEvent(KeyEvent event) {
    final player = widget.playerState.controller.player;
    final key = event.logicalKey;

    if (event is KeyDownEvent) {
      if (_lastSkipKey == key) return;

      if (key == LogicalKeyboardKey.space) {
        _togglePlayPause();
      } else if (key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight) {
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
      } else if (key == LogicalKeyboardKey.keyF ||
          key == LogicalKeyboardKey.f11) {
        _toggleFullscreen();
      } else if (key == LogicalKeyboardKey.escape) {
        if (_isFullscreenSafe()) {
          _toggleFullscreen();
        } else {
          _handleBack();
        }
      } else if (key == LogicalKeyboardKey.keyQ) {
        _handleBack();
      } else if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        final pos = player.state.position.inSeconds;
        final dur = player.state.duration.inSeconds;
        final isFinished =
            dur > 0 &&
            (dur - pos < PlaybackThresholds.completionRemainingSeconds ||
                (pos / dur) > PlaybackThresholds.completionPercentage);

        if (isFinished && widget.onNextEpisode != null) {
          widget.onNextEpisode!();
        }
      }
    } else if (event is KeyUpEvent) {
      if (key == _lastSkipKey) {
        _skipTimer?.cancel();
        _lastSkipKey = null;

        if (_virtualPosition != null) {
          ref
              .read(playerControllerProvider(widget.params).notifier)
              .seek(_virtualPosition!);

          _clearVirtualPositionTimer?.cancel();
          _clearVirtualPositionTimer = Timer(
            const Duration(milliseconds: 500),
            () {
              if (mounted) {
                setState(() {
                  _virtualPosition = null;
                });
              }
            },
          );
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
        seconds: (_virtualPosition!.inSeconds + offset).clamp(
          0,
          duration.inSeconds,
        ),
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
    _showSeekFeedback(forward);
    final player = widget.playerState.controller.player;
    final pos = player.state.position;
    final duration = player.state.duration;
    final target = Duration(
      seconds: (pos.inSeconds + (forward ? 10 : -10)).clamp(
        0,
        duration.inSeconds,
      ),
    );
    ref.read(playerControllerProvider(widget.params).notifier).seek(target);
    _onHover();
  }

  void _showSeekFeedback(bool forward) {
    _seekIndicatorTimer?.cancel();
    setState(() {
      _showSeekIndicator = true;
      if (forward) {
        _seekAmount = (_seekAmount > 0) ? _seekAmount + 10 : 10;
      } else {
        _seekAmount = (_seekAmount < 0) ? _seekAmount - 10 : -10;
      }
    });
    _seekIndicatorTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _showSeekIndicator = false;
          _seekAmount = 0;
        });
      }
    });
  }

  Future<void> _handleCastPressed(BuildContext context) async {
    if (widget.playerState.isCasting) {
      await ref
          .read(playerControllerProvider(widget.params).notifier)
          .stopCasting();
      return;
    }

    final device = await CastDeviceSelector.show(context);
    if (device != null) {
      await ref
          .read(playerControllerProvider(widget.params).notifier)
          .startCasting(device);
    }
  }

  void _onVerticalDragStart(DragStartDetails details) {
    _onHover(); // Show controls and restart timer
    final screenWidth = MediaQuery.of(context).size.width;
    if (details.globalPosition.dx < screenWidth / 2) {
      _currentDragType = DragType.brightness;
      _dragIndicatorValue = _brightnessLevel;
    } else {
      _currentDragType = DragType.volume;
      _dragIndicatorValue =
          widget.playerState.controller.player.state.volume / 100.0;
    }
    _hideIndicatorTimer?.cancel();
    setState(() {});
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_currentDragType == DragType.none) return;

    final screenHeight = MediaQuery.of(context).size.height;
    final delta = -(details.primaryDelta ?? 0) / screenHeight * 1.5;

    setState(() {
      if (_currentDragType == DragType.brightness) {
        _brightnessLevel = (_brightnessLevel + delta).clamp(0.0, 1.0);
        _dragIndicatorValue = _brightnessLevel;
      } else {
        final player = widget.playerState.controller.player;
        double currentVol = player.state.volume / 100.0;
        currentVol = (currentVol + delta).clamp(0.0, 1.0);
        player.setVolume(currentVol * 100.0);
        _dragIndicatorValue = currentVol;
      }
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    _hideIndicatorTimer?.cancel();
    _hideIndicatorTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _currentDragType = DragType.none;
        });
        _startHideTimer();
      }
    });
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _doubleTapPosition = details.globalPosition;
  }

  void _onDoubleTap() {
    if (_doubleTapPosition != null) {
      final screenWidth = MediaQuery.of(context).size.width;
      if (_doubleTapPosition!.dx < screenWidth / 2) {
        _performRealSkip(false);
      } else {
        _performRealSkip(true);
      }
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
        cursor: (_visible || !_isFullScreen)
            ? SystemMouseCursors.basic
            : SystemMouseCursors.none,
        child: GestureDetector(
          onTap: () {
            if (_visible) {
              _togglePlayPause();
            } else {
              _onHover();
            }
          },
          onDoubleTapDown: _onDoubleTapDown,
          onDoubleTap: _onDoubleTap,
          onVerticalDragStart: _onVerticalDragStart,
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              // Brightness overlay
              IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 1.0 - _brightnessLevel),
                ),
              ),
              AnimatedOpacity(
                opacity: _visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child:
                          (!_isFullScreen &&
                              (Platform.isWindows ||
                                  Platform.isLinux ||
                                  Platform.isMacOS))
                          ? DragToMoveArea(
                              child: VideoTopBar(
                                playerState: widget.playerState,
                                params: widget.params,
                                onSettingsPressed: widget.onSettingsPressed,
                                onCastPressed: () =>
                                    _handleCastPressed(context),
                                onBackPressed: _handleBack,
                              ),
                            )
                          : VideoTopBar(
                              playerState: widget.playerState,
                              params: widget.params,
                              onSettingsPressed: widget.onSettingsPressed,
                              onCastPressed: () => _handleCastPressed(context),
                              onBackPressed: _handleBack,
                            ),
                    ),

                    // Buffering / play-pause center overlay
                    BufferingIndicator(player: player),
                    PlayPauseOverlay(
                      player: player,
                      visible: _visible,
                      onTogglePlayPause: _togglePlayPause,
                      onSkip: _performRealSkip,
                    ),

                    SeekFeedbackOverlay(
                      amount: _seekAmount,
                      visible: _showSeekIndicator,
                    ),

                    // Drag Indicator Overlay
                    if (_currentDragType != DragType.none)
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 72.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _currentDragType == DragType.volume
                                      ? (_dragIndicatorValue == 0
                                            ? Icons.volume_off
                                            : Icons.volume_up)
                                      : Icons.brightness_6,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 100,
                                  height: 4,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: _dragIndicatorValue,
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

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
                          ref
                              .read(
                                playerControllerProvider(
                                  widget.params,
                                ).notifier,
                              )
                              .seek(target);
                          setState(() {
                            _dragging = false;
                            _virtualPosition = target;
                          });
                          _startHideTimer();
                          _clearVirtualPositionTimer?.cancel();
                          _clearVirtualPositionTimer = Timer(
                            const Duration(milliseconds: 500),
                            () {
                              if (mounted)
                                setState(() => _virtualPosition = null);
                            },
                          );
                        },
                        onChanged: (value) => setState(
                          () => _virtualPosition = Duration(
                            seconds: value.toInt(),
                          ),
                        ),
                        onTogglePlayPause: _togglePlayPause,
                        onSkip: _performRealSkip,
                        onToggleMute: _toggleMute,
                        isFullscreen: _isFullScreen,
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
