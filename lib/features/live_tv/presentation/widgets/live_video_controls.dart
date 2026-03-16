import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:cinemuse_app/core/presentation/widgets/volume_control.dart';
import 'package:cinemuse_app/core/presentation/widgets/fullscreen_button.dart';
import 'package:cinemuse_app/core/presentation/widgets/buffering_indicator.dart';
import 'package:cinemuse_app/core/presentation/widgets/play_pause_overlay.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/number_input_osd.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';

/// Full-featured controls overlay for the Live TV player.
///
/// Matches the visual style of [CustomVideoControls] but operates on the
/// unified [CinemaPlayerState].
class LiveVideoControls extends StatefulWidget {
  final CinemaPlayerState playerState;
  final Channel? channel;
  final mkv.VideoState videoState;

  /// Called when the user types a digit key (0–9).
  final ValueChanged<String>? onNumberInput;

  /// Called when the user presses Enter to confirm the typed number.
  final VoidCallback? onConfirmNumber;

  /// Current number input buffer to display in the OSD overlay.
  final String numberBuffer;

  const LiveVideoControls({
    super.key,
    required this.playerState,
    required this.channel,
    required this.videoState,
    this.onNumberInput,
    this.onConfirmNumber,
    this.numberBuffer = '',
  });

  @override
  State<LiveVideoControls> createState() => _LiveVideoControlsState();
}

class _LiveVideoControlsState extends State<LiveVideoControls> {
  bool _visible = true;
  Timer? _hideTimer;
  bool _dragging = false;
  Duration? _virtualPosition;
  Timer? _clearVirtualPositionTimer;
  double? _hoverX;
  Duration? _hoverDuration;
  bool _isHoveringSeekbar = false;
  final GlobalKey<VolumeControlState> _volumeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _clearVirtualPositionTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Visibility
  // ---------------------------------------------------------------------------

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_dragging && widget.playerState.controller.player.state.playing) {
        setState(() => _visible = false);
      }
    });
  }

  void _onHover() {
    if (!_visible) setState(() => _visible = true);
    _startHideTimer();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _togglePlayPause() {
    widget.playerState.controller.player.playOrPause();
    _onHover();
  }

  bool _isFullscreen() {
    try {
      return widget.videoState.isFullscreen();
    } catch (_) {
      return false;
    }
  }

  void _toggleFullscreen() {
    if (_isFullscreen()) {
      widget.videoState.exitFullscreen();
    } else {
      widget.videoState.enterFullscreen();
    }
    setState(() {});
  }

  void _seekToLive() async {
    final duration = widget.playerState.controller.player.state.duration;
    if (duration > Duration.zero) {
      try {
        // Seek to 5s before the edge to provide a safety buffer and prevent lag
        final target = duration - const Duration(seconds: 5);
        await widget.playerState.controller.player.seek(target > Duration.zero ? target : Duration.zero);
      } catch (_) {
        // Fallback or ignore
      }
    }
    setState(() {
      _virtualPosition = null;
    });
    _onHover();
  }

  // ---------------------------------------------------------------------------
  // Keyboard
  // ---------------------------------------------------------------------------

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.space) {
      _togglePlayPause();
    } else if (key == LogicalKeyboardKey.keyF) {
      _toggleFullscreen();
    } else if (key == LogicalKeyboardKey.keyM) {
      _volumeKey.currentState?.toggleMute();
      _onHover();
    } else if (key == LogicalKeyboardKey.arrowUp) {
      final vol = widget.playerState.controller.player.state.volume;
      widget.playerState.controller.player.setVolume((vol + 10).clamp(0, 100));
      _onHover();
    } else if (key == LogicalKeyboardKey.arrowDown) {
      final vol = widget.playerState.controller.player.state.volume;
      widget.playerState.controller.player.setVolume((vol - 10).clamp(0, 100));
      _onHover();
    } else if (key == LogicalKeyboardKey.arrowRight) {
      final pos = widget.playerState.controller.player.state.position;
      final dur = widget.playerState.controller.player.state.duration;
      if (dur > Duration.zero) {
        widget.playerState.controller.player.seek(Duration(seconds: (pos.inSeconds + 10).clamp(0, dur.inSeconds)));
      }
      _onHover();
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      final pos = widget.playerState.controller.player.state.position;
      widget.playerState.controller.player.seek(Duration(seconds: (pos.inSeconds - 10).clamp(0, pos.inSeconds)));
      _onHover();
    } else if (key == LogicalKeyboardKey.escape) {
      if (_isFullscreen()) {
        _toggleFullscreen();
      }
    }
  }


  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  String _formatDuration(Duration d) {
    final totalSeconds = d.inSeconds.abs();
    final negative = d.isNegative;
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    final prefix = negative ? '-' : '';
    if (h > 0) {
      return '$prefix$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$prefix$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
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
              // Buffering indicator (always visible)
              BufferingIndicator(player: widget.playerState.controller.player),

              // Controls layer
              AnimatedOpacity(
                opacity: _visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_visible,
                  child: Stack(
                    children: [
                      // Top bar
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _buildTopBar(),
                      ),

                      // Play/Pause center overlay
                      PlayPauseOverlay(player: widget.playerState.controller.player, visible: _visible),

                      // Bottom bar
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: _buildBottomBar(),
                      ),
                    ],
                  ),
                ),
              ),

              // Number input OSD (always visible, above controls)
              if (widget.numberBuffer.isNotEmpty)
                NumberInputOsd(buffer: widget.numberBuffer),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top bar — channel name + logo, no settings cog
  // ---------------------------------------------------------------------------

  Widget _buildTopBar() {
    return Container(
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
          if (_isFullscreen())
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: _toggleFullscreen,
            ),
          if (_isFullscreen()) const SizedBox(width: 8),
          // Channel logo
          if (widget.channel != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 28,
                height: 28,
                child: Image.network(
                  widget.channel!.logoUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.channel!.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom bar with stable seek bar + controls
  // ---------------------------------------------------------------------------

  Widget _buildBottomBar() {
    return Container(
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
          _buildSeekBar(),
          _buildControlsRow(),
        ],
      ),
    );
  }

  /// Seek bar using raw position/duration.
  ///
  /// When at the live edge (within 5s of duration), position is snapped
  /// to duration so the thumb sits stable at the far right instead of
  /// jittering as duration grows every second.
  Widget _buildSeekBar() {
    return StreamBuilder<Duration>(
      stream: widget.playerState.controller.player.stream.position,
      builder: (context, snapshot) {
        final rawDuration = widget.playerState.controller.player.state.duration;
        final rawPosition = _virtualPosition ?? snapshot.data ?? Duration.zero;

        if (rawDuration <= Duration.zero) return const SizedBox.shrink();

        // 1. Calculate relative offset from live (0 is Live)
        // Values will be negative, e.g., -120 means 2 minutes behind live.
        final secondsBehindLive = -(rawDuration.inSeconds - rawPosition.inSeconds).toDouble();

        // 2. Stabilize the seekbar window (the "min" value)
        // We use the actual available duration but round up ONLY the UI scale
        // to the next 60-second increment to prevent jitter every second.
        // We clamp the actual seek within rawDuration in onChange.
        final uiTotalSeconds = ((rawDuration.inSeconds / 60).ceil() * 60).toDouble().clamp(60.0, 7200.0);
        
        // Final sanity check for slider limits: the slider range [-uiTotalSeconds, 0]
        // must always contain the current position.
        final safeMin = -uiTotalSeconds;

        // 3. Determine if we are "At Live"
        // Most streams have a safety buffer of 1-3 segments (~18s).
        // We treat anything within 30s of the edge as "LIVE" for UI stability.
        final isAtLive = !_dragging && secondsBehindLive >= -30;

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
                        // Convert percent to seconds behind live relative to UI scale
                        final hoverSeconds = -((1.0 - percent) * uiTotalSeconds);
                        _hoverDuration = Duration(seconds: hoverSeconds.toInt().abs());
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
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                            activeTrackColor: AppTheme.accent,
                            inactiveTrackColor: AppTheme.textWhite.withOpacity(0.24),
                            thumbColor: AppTheme.textWhite,
                            activeTickMarkColor: Colors.transparent,
                            inactiveTickMarkColor: Colors.transparent,
                          ),
                          child: Slider(
                            // We slider from safeMin (past) to 0 (Live)
                            value: isAtLive ? 0 : secondsBehindLive.clamp(safeMin, 0),
                            min: safeMin,
                            max: 0,
                            onChangeStart: (v) {
                              setState(() {
                                _dragging = true;
                                // Clamp virtual position within rawDuration to avoid "jump back"
                                final clampedOffset = v.clamp(-rawDuration.inSeconds.toDouble(), 0.0);
                                _virtualPosition = rawDuration + Duration(seconds: clampedOffset.toInt());
                              });
                              _hideTimer?.cancel();
                              _clearVirtualPositionTimer?.cancel();
                            },
                            onChanged: (v) {
                              setState(() {
                                final clampedOffset = v.clamp(-rawDuration.inSeconds.toDouble(), 0.0);
                                _virtualPosition = rawDuration + Duration(seconds: clampedOffset.toInt());
                              });
                            },
                            onChangeEnd: (v) async {
                              final clampedOffset = v.clamp(-rawDuration.inSeconds.toDouble(), 0.0);
                              final target = rawDuration + Duration(seconds: clampedOffset.toInt());
                              try {
                                await widget.playerState.controller.player.seek(target);
                              } catch (_) {
                                // Ignore seek errors on some problematic live streams or if force-seekable fails
                              }
                              setState(() {
                                _dragging = false;
                                _virtualPosition = target;
                              });
                              _startHideTimer();
                              _clearVirtualPositionTimer?.cancel();
                              _clearVirtualPositionTimer = Timer(const Duration(milliseconds: 1000), () {
                                if (mounted) setState(() => _virtualPosition = null);
                              });
                            },
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
                                '-${_formatDuration(_hoverDuration!)}',
                                style: const TextStyle(
                                  color: AppTheme.textWhite,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 70,
              alignment: Alignment.centerRight,
              child: Text(
                isAtLive ? 'LIVE' : '-${_formatDuration(Duration(seconds: secondsBehindLive.toInt().abs()))}',
                style: TextStyle(
                  color: isAtLive ? AppTheme.favorites : AppTheme.textWhite,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlsRow() {
    return Row(
      children: [
        // Play/Pause
        StreamBuilder<bool>(
          stream: widget.playerState.controller.player.stream.playing,
          initialData: widget.playerState.controller.player.state.playing,
          builder: (context, snapshot) {
            final isPlaying = snapshot.data ?? false;
            return IconButton(
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32,
              ),
              onPressed: _togglePlayPause,
            );
          },
        ),
        // Volume
        VolumeControl(key: _volumeKey, player: widget.playerState.controller.player),
        const SizedBox(width: 8),
        // LIVE pill
        _LivePill(player: widget.playerState.controller.player, onTap: _seekToLive),
        const Spacer(),
        // Fullscreen
        FullscreenButton(
          isFullscreen: _isFullscreen(),
          onToggle: _toggleFullscreen,
        ),
      ],
    );
  }
}

// =============================================================================
// LIVE indicator pill
// =============================================================================

class _LivePill extends StatelessWidget {
  final Player player;
  final VoidCallback onTap;

  const _LivePill({required this.player, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.stream.position,
      builder: (context, posSnap) {
        final position = posSnap.data ?? Duration.zero;
        final duration = player.state.duration;
        // Consider "at live" if within 30 seconds of the end for stability
        final isAtLive = duration <= Duration.zero || (duration - position).inSeconds.abs() < 30;

        return GestureDetector(
          onTap: isAtLive ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isAtLive ? AppTheme.favorites : Colors.white10,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isAtLive ? [
                BoxShadow(
                  color: AppTheme.favorites.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 0,
                )
              ] : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isAtLive)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const Icon(Icons.arrow_forward, size: 12, color: AppTheme.favorites),
                const SizedBox(width: 6),
                Text(
                  isAtLive ? 'LIVE' : 'JUMP TO LIVE',
                  style: TextStyle(
                    color: isAtLive ? Colors.white : AppTheme.favorites,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
