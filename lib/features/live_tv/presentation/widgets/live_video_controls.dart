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
  final GlobalKey<VolumeControlState> _volumeKey = GlobalKey();

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

  // ---------------------------------------------------------------------------
  // Visibility
  // ---------------------------------------------------------------------------

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && widget.playerState.controller.player.state.playing) {
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

  void _seekToLive() {
    final duration = widget.playerState.controller.player.state.duration;
    if (duration > Duration.zero) {
      widget.playerState.controller.player.seek(duration);
    }
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
        final position = snapshot.data ?? Duration.zero;
        final duration = widget.playerState.controller.player.state.duration;
        final maxSecs = duration.inSeconds.toDouble();

        if (maxSecs <= 0) return const SizedBox.shrink();

        // Snap to live edge when within 5 seconds to prevent jitter
        final behindLive = duration - position;
        final isAtLive = behindLive.inSeconds.abs() < 5;
        final effectivePos = isAtLive ? maxSecs : position.inSeconds.toDouble().clamp(0.0, maxSecs);

        return Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: effectivePos,
                  min: 0,
                  max: maxSecs,
                  onChanged: (v) => widget.playerState.controller.player.seek(Duration(seconds: v.toInt())),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isAtLive
                  ? 'LIVE'
                  : '-${_formatDuration(behindLive)}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontFamily: 'monospace',
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
        // Consider "at live" if within 5 seconds of the end
        final isAtLive = duration <= Duration.zero || (duration - position).inSeconds.abs() < 5;

        return GestureDetector(
          onTap: isAtLive ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isAtLive ? Colors.red : Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isAtLive ? Colors.white : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'LIVE',
                  style: TextStyle(
                    color: isAtLive ? Colors.white : Colors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
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
