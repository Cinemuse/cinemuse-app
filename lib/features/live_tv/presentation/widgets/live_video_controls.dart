import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:window_manager/window_manager.dart';
import 'package:cinemuse_app/core/application/display_mode_provider.dart';
import 'package:cinemuse_app/core/presentation/widgets/volume_control.dart';
import 'package:cinemuse_app/core/presentation/widgets/fullscreen_button.dart';
import 'package:cinemuse_app/core/presentation/widgets/buffering_indicator.dart';
import 'package:cinemuse_app/core/presentation/widgets/play_pause_overlay.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/number_input_osd.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_list_panel.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

enum DragType { none, volume, brightness }

/// Full-featured controls overlay for the Live TV player.
///
/// Matches the visual style of [CustomVideoControls] but operates on the
/// unified [CinemaPlayerState].
class LiveVideoControls extends ConsumerStatefulWidget {
  final CinemaPlayerState playerState;
  final Channel? channel;
  final mkv.VideoState videoState;

  /// Called when the user types a digit key (0–9).
  final ValueChanged<String>? onNumberInput;

  /// Called when the user presses Enter to confirm the typed number.
  final VoidCallback? onConfirmNumber;

  /// Current number input buffer to display in the OSD overlay.
  final String numberBuffer;
  final VoidCallback? onSettingsPressed;

  const LiveVideoControls({
    super.key,
    required this.playerState,
    required this.channel,
    required this.videoState,
    this.onNumberInput,
    this.onConfirmNumber,
    this.numberBuffer = '',
    this.onSettingsPressed,
  });

  @override
  ConsumerState<LiveVideoControls> createState() => _LiveVideoControlsState();
}

class _LiveVideoControlsState extends ConsumerState<LiveVideoControls> {
  final FocusNode _rootFocusNode =
      FocusNode(debugLabel: 'LiveVideoControlsRoot');
  late final FocusNode _rewindFocusNode;
  late final FocusNode _playPauseFocusNode;
  late final FocusNode _forwardFocusNode;
  late final FocusNode _liveFocusNode;
  late final FocusNode _channelsFocusNode;
  late final FocusNode _settingsFocusNode;
  late final FocusNode _viewModeFocusNode;
  late final FocusNode _fullscreenFocusNode;

  bool _visible = true;
  Timer? _hideTimer;
  bool _dragging = false;
  Duration? _virtualPosition;
  Timer? _clearVirtualPositionTimer;
  double? _hoverX;
  Duration? _hoverDuration;
  bool _isHoveringSeekbar = false;
  final GlobalKey<VolumeControlState> _volumeKey = GlobalKey();
  bool _isFullScreen = false;

  /// Tracks whether the window was already maximized before we entered
  /// fullscreen, so we can restore the original state on exit.
  bool _wasMaximizedBeforeFullscreen = false;

  DragType _currentDragType = DragType.none;
  double _brightnessLevel = 1.0; // 0.0 to 1.0
  Timer? _hideIndicatorTimer;
  double _dragIndicatorValue = 0.0;
  Offset? _doubleTapPosition;

  bool _showSeekIndicator = false;
  int _seekAmount = 0;
  Timer? _seekIndicatorTimer;

  @override
  void initState() {
    super.initState();
    _rewindFocusNode = FocusNode(debugLabel: 'LiveRewindTvButton');
    _playPauseFocusNode = FocusNode(debugLabel: 'LivePlayPauseTvButton');
    _forwardFocusNode = FocusNode(debugLabel: 'LiveForwardTvButton');
    _liveFocusNode = FocusNode(debugLabel: 'LiveCatchUpTvButton');
    _channelsFocusNode = FocusNode(debugLabel: 'LiveChannelsTvButton');
    _settingsFocusNode = FocusNode(debugLabel: 'LiveSettingsTvButton');
    _viewModeFocusNode = FocusNode(debugLabel: 'LiveViewModeTvButton');
    _fullscreenFocusNode = FocusNode(debugLabel: 'LiveFullscreenTvButton');

    _startHideTimer();
    _initFullscreenState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncFocusForVisibility();
    });
  }

  void _initFullscreenState() {
    if (mounted) setState(() => _isFullScreen = _isFullscreen());
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _clearVirtualPositionTimer?.cancel();
    _hideIndicatorTimer?.cancel();
    _seekIndicatorTimer?.cancel();
    _rewindFocusNode.dispose();
    _playPauseFocusNode.dispose();
    _forwardFocusNode.dispose();
    _liveFocusNode.dispose();
    _channelsFocusNode.dispose();
    _settingsFocusNode.dispose();
    _viewModeFocusNode.dispose();
    _fullscreenFocusNode.dispose();
    _rootFocusNode.dispose();
    super.dispose();
  }

  void _syncFocusForVisibility() {
    final isBigPicture = ref.read(isBigPictureProvider);
    if (!isBigPicture) {
      _rootFocusNode.requestFocus();
      return;
    }
    if (_visible) {
      _playPauseFocusNode.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _visible) {
          _playPauseFocusNode.requestFocus();
        }
      });
    } else {
      _rootFocusNode.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_visible) {
          _rootFocusNode.requestFocus();
        }
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Visibility
  // ---------------------------------------------------------------------------

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted &&
          !_dragging &&
          _currentDragType == DragType.none &&
          !ref.read(liveTvChannelOverlayProvider) &&
          widget.playerState.controller.player.state.playing) {
        _hideControls();
      }
    });
  }

  void _showControls() {
    final wasHidden = !_visible;
    if (wasHidden) {
      setState(() => _visible = true);
    }
    _startHideTimer();
    if (wasHidden) {
      _syncFocusForVisibility();
    }
  }

  void _hideControls() {
    if (_visible) {
      setState(() => _visible = false);
      _syncFocusForVisibility();
    }
  }

  void _onHover() {
    _showControls();
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

  Future<void> _toggleFullscreen() async {
    if (_isFullscreen()) {
      await widget.videoState.exitFullscreen();
      if ((Platform.isWindows || Platform.isLinux) &&
          !_wasMaximizedBeforeFullscreen) {
        await windowManager.unmaximize();
      }
      if (mounted) setState(() => _isFullScreen = false);
    } else {
      if (Platform.isWindows || Platform.isLinux) {
        _wasMaximizedBeforeFullscreen = await windowManager.isMaximized();
        if (!_wasMaximizedBeforeFullscreen) {
          await windowManager.maximize();
        }
      }
      await widget.videoState.enterFullscreen();
      if (mounted) setState(() => _isFullScreen = true);
    }
  }

  void _seekToLive() async {
    final duration = widget.playerState.controller.player.state.duration;
    if (duration > Duration.zero) {
      try {
        // Seek to 5s before the edge to provide a safety buffer and prevent lag
        final target = duration - const Duration(seconds: 5);
        await widget.playerState.controller.player.seek(
          target > Duration.zero ? target : Duration.zero,
        );
      } catch (_) {
        // Fallback or ignore
      }
    }
    setState(() {
      _virtualPosition = null;
    });
    _onHover();
  }

  void _performSkip(bool forward) {
    _showSeekFeedback(forward);
    final pos = widget.playerState.controller.player.state.position;
    final dur = widget.playerState.controller.player.state.duration;
    if (forward) {
      if (dur > Duration.zero) {
        widget.playerState.controller.player.seek(
          Duration(seconds: (pos.inSeconds + 10).clamp(0, dur.inSeconds)),
        );
      }
    } else {
      widget.playerState.controller.player.seek(
        Duration(seconds: (pos.inSeconds - 10).clamp(0, pos.inSeconds)),
      );
    }
    _onHover();
  }

  void _showSeekFeedback(bool forward) {
    _seekIndicatorTimer?.cancel();
    setState(() {
      _showSeekIndicator = true;
      if (_seekAmount == 0) {
        _seekAmount = forward ? 10 : -10;
      } else {
        if (forward) {
          _seekAmount = _seekAmount > 0 ? _seekAmount + 10 : 10;
        } else {
          _seekAmount = _seekAmount < 0 ? _seekAmount - 10 : -10;
        }
      }
    });

    // Auto-reset after 1 second of inactivity
    _seekIndicatorTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _showSeekIndicator = false;
          _seekAmount = 0;
        });
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Keyboard
  // ---------------------------------------------------------------------------

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final isOverlayOpen = ref.read(liveTvChannelOverlayProvider);
    final isFullWindow =
        ref.read(liveTvViewModeProvider) == LiveTvViewMode.fullWindow;
    final isBigPicture = ref.read(isBigPictureProvider);

    // When overlay is open: Escape, Gamepad B, or Right closes it
    if (isOverlayOpen) {
      if (key == LogicalKeyboardKey.escape ||
          key == LogicalKeyboardKey.gameButtonB ||
          key == LogicalKeyboardKey.arrowRight) {
        ref.read(liveTvChannelOverlayProvider.notifier).state = false;
        _onHover();
        return KeyEventResult.handled;
      }
    }

    // Direct channel number input (0–9) always works whether controls are visible or not
    if (widget.onNumberInput != null) {
      final keyLabel = key.keyLabel;
      if (keyLabel.length == 1 && int.tryParse(keyLabel) != null) {
        widget.onNumberInput!(keyLabel);
        _onHover();
        return KeyEventResult.handled;
      }
    }

    if (!_visible) {
      return _handleHiddenControlsKeys(key, isFullWindow, isBigPicture);
    }

    return _handleVisibleControlsKeys(key, isFullWindow, isBigPicture);
  }

  KeyEventResult _handleHiddenControlsKeys(
    LogicalKeyboardKey key,
    bool isFullWindow,
    bool isBigPicture,
  ) {
    if (key == LogicalKeyboardKey.space) {
      _togglePlayPause();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      _showControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (isFullWindow || _isFullScreen) {
        ref.read(liveTvChannelOverlayProvider.notifier).state = true;
      } else {
        _performSkip(false);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _performSkip(true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.goBack) {
      if (_isFullScreen) {
        _toggleFullscreen();
      } else if (isFullWindow) {
        ref.read(liveTvViewModeProvider.notifier).state = LiveTvViewMode.split;
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF || key == LogicalKeyboardKey.f11) {
      _toggleFullscreen();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyM) {
      _volumeKey.currentState?.toggleMute();
      _onHover();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleVisibleControlsKeys(
    LogicalKeyboardKey key,
    bool isFullWindow,
    bool isBigPicture,
  ) {
    _startHideTimer();

    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.goBack) {
      _hideControls();
      return KeyEventResult.handled;
    }

    if (isBigPicture) {
      if (key == LogicalKeyboardKey.arrowDown) {
        _hideControls();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.space) {
        _togglePlayPause();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Standard desktop visible controls keys
    if (key == LogicalKeyboardKey.space) {
      _togglePlayPause();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF) {
      _toggleFullscreen();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyM) {
      _volumeKey.currentState?.toggleMute();
      _onHover();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      final vol = widget.playerState.controller.player.state.volume;
      widget.playerState.controller.player.setVolume((vol + 10).clamp(0, 100));
      _onHover();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      final vol = widget.playerState.controller.player.state.volume;
      widget.playerState.controller.player.setVolume((vol - 10).clamp(0, 100));
      _onHover();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _performSkip(true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (isFullWindow || _isFullScreen) {
        ref.read(liveTvChannelOverlayProvider.notifier).state = true;
      } else {
        _performSkip(false);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
        _performSkip(false);
      } else {
        _performSkip(true);
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
    final viewMode = ref.watch(liveTvViewModeProvider);
    final isFullWindow = viewMode == LiveTvViewMode.fullWindow;
    final isBigPicture = ref.watch(isBigPictureProvider);

    return Focus(
      focusNode: _rootFocusNode,
      autofocus: true,
      canRequestFocus: !isBigPicture || !_visible,
      onKeyEvent: (_, event) => _handleKeyEvent(event),
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
                        child: ExcludeFocus(
                          excluding: isBigPicture,
                          child: _buildTopBar(isFullWindow, isBigPicture),
                        ),
                      ),

                      // Play/Pause center overlay
                      PlayPauseOverlay(
                        player: widget.playerState.controller.player,
                        visible: _visible,
                        onTogglePlayPause: _togglePlayPause,
                        onSkip: _performSkip,
                        seekAmount: _seekAmount,
                        showSeekIndicator: _showSeekIndicator,
                      ),

                      // Bottom bar
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: ExcludeFocus(
                          excluding: !_visible,
                          child: _buildBottomBar(
                            context,
                            isFullWindow,
                            isBigPicture,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Drag Indicator Overlay (always above video and darkening)
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
                                valueColor: const AlwaysStoppedAnimation<Color>(
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

              // Number input OSD (always visible, above controls)
              if (widget.numberBuffer.isNotEmpty)
                NumberInputOsd(buffer: widget.numberBuffer),

              // Channel List Overlay Drawer (accessible in full-window & OS fullscreen)
              _buildChannelOverlayDrawer(isFullWindow),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelOverlayDrawer(bool isFullWindow) {
    if (!isFullWindow && !_isFullScreen) return const SizedBox.shrink();

    final isOverlayOpen = ref.watch(liveTvChannelOverlayProvider);
    if (!isOverlayOpen) return const SizedBox.shrink();

    return Stack(
      children: [
        // Semi-transparent backdrop outside drawer: tap to dismiss
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              ref.read(liveTvChannelOverlayProvider.notifier).state = false;
            },
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 360,
          child: RepaintBoundary(
            child: ChannelListPanel(
              isOverlay: true,
              onClose: () {
                ref.read(liveTvChannelOverlayProvider.notifier).state = false;
              },
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Top bar — channel name, logo, and settings cog
  // ---------------------------------------------------------------------------

  Widget _buildTopBar(bool isFullWindow, bool isBigPicture) {
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
          if (isFullWindow) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back, color: AppTheme.textWhite),
              tooltip: 'Back',
              onPressed: () {
                _onHover();
                ref.read(liveTvViewModeProvider.notifier).state =
                    LiveTvViewMode.split;
              },
            ),
            const SizedBox(width: 8),
          ],
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
                  cacheWidth: 56,
                  cacheHeight: 56,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.channel!.name,
              style: const TextStyle(
                color: AppTheme.textWhite,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          const Spacer(),
          if (!isBigPicture && widget.onSettingsPressed != null)
            IconButton(
              icon: const Icon(Icons.settings, color: AppTheme.textWhite),
              onPressed: () {
                _onHover(); // Keep controls visible while settings open
                widget.onSettingsPressed!();
              },
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom bar with stable seek bar + controls
  // ---------------------------------------------------------------------------

  Widget _buildBottomBar(
    BuildContext context,
    bool isFullWindow,
    bool isBigPicture,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            AppTheme.primary.withValues(alpha: 0.87),
            Colors.transparent,
          ],
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: isBigPicture ? 16 : 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSeekBar(isBigPicture),
          if (isBigPicture)
            _buildBigPictureControls(context, isFullWindow, l10n)
          else
            _buildStandardControls(context, isFullWindow, l10n),
        ],
      ),
    );
  }

  /// Seek bar using raw position/duration.
  ///
  /// When at the live edge (within 5s of duration), position is snapped
  /// to duration so the thumb sits stable at the far right instead of
  /// jittering as duration grows every second.
  Widget _buildSeekBar(bool isBigPicture) {
    return StreamBuilder<Duration>(
      stream: widget.playerState.controller.player.stream.position,
      builder: (context, snapshot) {
        final rawDuration = widget.playerState.controller.player.state.duration;
        final rawPosition = _virtualPosition ?? snapshot.data ?? Duration.zero;

        if (rawDuration <= Duration.zero) return const SizedBox.shrink();

        // 1. Calculate relative offset from live (0 is Live)
        final secondsBehindLive =
            -(rawDuration.inSeconds - rawPosition.inSeconds).toDouble();

        // 2. Stabilize the seekbar window (the "min" value)
        final uiTotalSeconds = ((rawDuration.inSeconds / 60).ceil() * 60)
            .toDouble()
            .clamp(60.0, 7200.0);
        final safeMin = -uiTotalSeconds;

        // 3. Determine if we are "At Live"
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
                        final percent = (_hoverX! / constraints.maxWidth).clamp(
                          0.0,
                          1.0,
                        );
                        final hoverSeconds =
                            -((1.0 - percent) * uiTotalSeconds);
                        _hoverDuration = Duration(
                          seconds: hoverSeconds.toInt().abs(),
                        );
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
                        ExcludeFocus(
                          excluding: isBigPicture,
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: isBigPicture ? 4 : 3,
                              thumbShape: RoundSliderThumbShape(
                                enabledThumbRadius: isBigPicture ? 8 : 7,
                              ),
                              overlayShape: RoundSliderOverlayShape(
                                overlayRadius: isBigPicture ? 16 : 14,
                              ),
                              activeTrackColor: AppTheme.textWhite,
                              inactiveTrackColor: AppTheme.textWhite.withValues(
                                alpha: 0.24,
                              ),
                              thumbColor: AppTheme.textWhite,
                              activeTickMarkColor: Colors.transparent,
                              inactiveTickMarkColor: Colors.transparent,
                            ),
                            child: Slider(
                              value: isAtLive
                                  ? 0
                                  : secondsBehindLive.clamp(safeMin, 0),
                              min: safeMin,
                              max: 0,
                              onChangeStart: (v) {
                                setState(() {
                                  _dragging = true;
                                  final clampedOffset = v.clamp(
                                    -rawDuration.inSeconds.toDouble(),
                                    0.0,
                                  );
                                  _virtualPosition =
                                      rawDuration +
                                      Duration(seconds: clampedOffset.toInt());
                                });
                                _hideTimer?.cancel();
                                _clearVirtualPositionTimer?.cancel();
                              },
                              onChanged: (v) {
                                setState(() {
                                  final clampedOffset = v.clamp(
                                    -rawDuration.inSeconds.toDouble(),
                                    0.0,
                                  );
                                  _virtualPosition =
                                      rawDuration +
                                      Duration(seconds: clampedOffset.toInt());
                                });
                              },
                              onChangeEnd: (v) async {
                                final clampedOffset = v.clamp(
                                  -rawDuration.inSeconds.toDouble(),
                                  0.0,
                                );
                                final target =
                                    rawDuration +
                                    Duration(seconds: clampedOffset.toInt());
                                try {
                                  await widget.playerState.controller.player.seek(
                                    target,
                                  );
                                } catch (_) {}
                                setState(() {
                                  _dragging = false;
                                  _virtualPosition = target;
                                });
                                _startHideTimer();
                                _clearVirtualPositionTimer?.cancel();
                                _clearVirtualPositionTimer = Timer(
                                  const Duration(milliseconds: 1000),
                                  () {
                                    if (mounted) {
                                      setState(() => _virtualPosition = null);
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                        if (_isHoveringSeekbar &&
                            _hoverX != null &&
                            _hoverDuration != null)
                          Positioned(
                            left: (_hoverX! - 35).clamp(
                              0,
                              constraints.maxWidth - 70,
                            ),
                            top: -35,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AppTheme.textWhite.withValues(
                                    alpha: 0.24,
                                  ),
                                  width: 0.5,
                                ),
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
              width: isBigPicture ? 80 : 70,
              alignment: Alignment.centerRight,
              child: Text(
                isAtLive
                    ? 'LIVE'
                    : '-${_formatDuration(Duration(seconds: secondsBehindLive.toInt().abs()))}',
                style: TextStyle(
                  color: isAtLive ? AppTheme.favorites : AppTheme.textWhite,
                  fontSize: isBigPicture ? 15 : 12,
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

  // ---------------------------------------------------------------------------
  // Big Picture TV Controls
  // ---------------------------------------------------------------------------

  Widget _buildBigPictureControls(
    BuildContext context,
    bool isFullWindow,
    AppLocalizations l10n,
  ) {
    final player = widget.playerState.controller.player;
    final isOverlayOpen = ref.watch(liveTvChannelOverlayProvider);
    final showChannels = isFullWindow || _isFullScreen;
    final showSettings = widget.onSettingsPressed != null;

    final chain = <FocusNode>[
      _rewindFocusNode,
      _playPauseFocusNode,
      _forwardFocusNode,
      _liveFocusNode,
      if (showChannels) _channelsFocusNode,
      if (showSettings) _settingsFocusNode,
      _viewModeFocusNode,
      _fullscreenFocusNode,
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Rewind 10s
          _buildTvIconButton(
            icon: Icons.replay_10_rounded,
            tooltip: l10n.playerSkipBackward,
            focusNode: _rewindFocusNode,
            onKeyEvent: (node, event) =>
                _handleChainKey(event, _rewindFocusNode, chain, isFullWindow),
            onTap: () => _performSkip(false),
          ),
          const SizedBox(width: 16),
          // Play / Pause (large, centered)
          _buildPlayPauseTvButton(player, chain, isFullWindow),
          const SizedBox(width: 16),
          // Forward 10s
          _buildTvIconButton(
            icon: Icons.forward_10_rounded,
            tooltip: l10n.playerSkipForward,
            focusNode: _forwardFocusNode,
            onKeyEvent: (node, event) =>
                _handleChainKey(event, _forwardFocusNode, chain, isFullWindow),
            onTap: () => _performSkip(true),
          ),
          const SizedBox(width: 16),
          // LIVE catch-up
          _buildTvIconButton(
            icon: Icons.sensors_rounded,
            tooltip: l10n.liveTvGoToLive,
            focusNode: _liveFocusNode,
            onKeyEvent: (node, event) =>
                _handleChainKey(event, _liveFocusNode, chain, isFullWindow),
            onTap: _seekToLive,
          ),
          // Channels drawer (in full-window or fullscreen)
          if (showChannels) ...[
            const SizedBox(width: 16),
            _buildTvIconButton(
              icon: isOverlayOpen
                  ? Icons.view_sidebar_rounded
                  : Icons.view_sidebar_outlined,
              tooltip: l10n.liveTvChannels,
              focusNode: _channelsFocusNode,
              onKeyEvent: (node, event) =>
                  _handleChainKey(event, _channelsFocusNode, chain, isFullWindow),
              onTap: () {
                _onHover();
                ref.read(liveTvChannelOverlayProvider.notifier).state =
                    !isOverlayOpen;
              },
            ),
          ],
          // Settings (if provided)
          if (showSettings) ...[
            const SizedBox(width: 16),
            _buildTvIconButton(
              icon: Icons.tune_rounded,
              tooltip: l10n.playerSettings,
              focusNode: _settingsFocusNode,
              onKeyEvent: (node, event) =>
                  _handleChainKey(event, _settingsFocusNode, chain, isFullWindow),
              onTap: () {
                _onHover();
                widget.onSettingsPressed!();
              },
            ),
          ],
          const SizedBox(width: 16),
          // View Mode (Full Window / Split)
          _buildTvIconButton(
            icon: isFullWindow
                ? Icons.view_quilt_rounded
                : Icons.aspect_ratio_rounded,
            tooltip: isFullWindow ? l10n.liveTvSplitView : l10n.liveTvFullWindow,
            focusNode: _viewModeFocusNode,
            onKeyEvent: (node, event) =>
                _handleChainKey(event, _viewModeFocusNode, chain, isFullWindow),
            onTap: () {
              _onHover();
              ref.read(liveTvViewModeProvider.notifier).state = isFullWindow
                  ? LiveTvViewMode.split
                  : LiveTvViewMode.fullWindow;
            },
          ),
          const SizedBox(width: 16),
          // Fullscreen
          _buildTvIconButton(
            icon: _isFullScreen
                ? Icons.fullscreen_exit_rounded
                : Icons.fullscreen_rounded,
            tooltip: _isFullScreen
                ? l10n.playerExitFullscreen
                : l10n.playerFullscreen,
            focusNode: _fullscreenFocusNode,
            onKeyEvent: (node, event) =>
                _handleChainKey(event, _fullscreenFocusNode, chain, isFullWindow),
            onTap: _toggleFullscreen,
          ),
        ],
      ),
    );
  }

  KeyEventResult _handleChainKey(
    KeyEvent event,
    FocusNode current,
    List<FocusNode> chain,
    bool isFullWindow,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      final index = chain.indexOf(current);
      if (index > 0) {
        chain[index - 1].requestFocus();
        return KeyEventResult.handled;
      } else if (index == 0 && (isFullWindow || _isFullScreen)) {
        // Pressing Left from the first button opens the channel overlay drawer!
        ref.read(liveTvChannelOverlayProvider.notifier).state = true;
        return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      final index = chain.indexOf(current);
      if (index >= 0 && index < chain.length - 1) {
        chain[index + 1].requestFocus();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  Widget _buildPlayPauseTvButton(
    Player player,
    List<FocusNode> chain,
    bool isFullWindow,
  ) {
    return StreamBuilder<bool>(
      stream: player.stream.playing,
      initialData: player.state.playing,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data ?? player.state.playing;
        return _buildTvIconButton(
          icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          tooltip: isPlaying ? 'Pause' : 'Play',
          focusNode: _playPauseFocusNode,
          autofocus: true,
          iconSize: 34,
          buttonSize: 52,
          onKeyEvent: (node, event) =>
              _handleChainKey(event, _playPauseFocusNode, chain, isFullWindow),
          onTap: _togglePlayPause,
        );
      },
    );
  }

  Widget _buildTvIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    FocusNode? focusNode,
    FocusOnKeyEventCallback? onKeyEvent,
    bool autofocus = false,
    double iconSize = 28,
    double buttonSize = 48,
    Color? iconColor,
  }) {
    return DpadFocusable(
      focusNode: focusNode,
      onKeyEvent: onKeyEvent,
      autofocus: autofocus,
      onTap: onTap,
      scale: 1.12,
      borderRadius: BorderRadius.circular(buttonSize / 2),
      builder: (context, isFocused, isHovered, child) {
        final isHighlighted = isFocused || isHovered;
        return Tooltip(
          message: tooltip,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isHighlighted
                  ? Colors.white.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.08),
              border: Border.all(
                color: isFocused
                    ? Colors.white
                    : (isHovered
                        ? Colors.white.withValues(alpha: 0.4)
                        : Colors.transparent),
                width: 2,
              ),
              boxShadow: isFocused ? AppTheme.shadowFocusGlow : null,
            ),
            child: Icon(
              icon,
              color: iconColor ?? Colors.white,
              size: iconSize,
            ),
          ),
        );
      },
      child: const SizedBox.shrink(),
    );
  }

  // ---------------------------------------------------------------------------
  // Standard Controls (Compact / Mobile)
  // ---------------------------------------------------------------------------

  Widget _buildStandardControls(
    BuildContext context,
    bool isFullWindow,
    AppLocalizations l10n,
  ) {
    final isOverlayOpen = ref.watch(liveTvChannelOverlayProvider);

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
        VolumeControl(
          key: _volumeKey,
          player: widget.playerState.controller.player,
        ),
        const SizedBox(width: 8),
        // LIVE pill
        _LivePill(
          player: widget.playerState.controller.player,
          onTap: _seekToLive,
        ),
        const Spacer(),
        // Channel list overlay toggle (visible in full window or OS fullscreen)
        if (isFullWindow || _isFullScreen)
          IconButton(
            icon: Icon(
              isOverlayOpen
                  ? Icons.view_sidebar_rounded
                  : Icons.view_sidebar_outlined,
              color: isOverlayOpen ? Colors.white : Colors.white70,
            ),
            tooltip: l10n.liveTvChannels,
            onPressed: () {
              _onHover();
              ref.read(liveTvChannelOverlayProvider.notifier).state =
                  !isOverlayOpen;
            },
          ),
        // Full Window / Split toggle
        IconButton(
          icon: Icon(
            isFullWindow
                ? Icons.view_quilt_rounded
                : Icons.aspect_ratio_rounded,
            color: Colors.white,
          ),
          tooltip: isFullWindow ? l10n.liveTvSplitView : l10n.liveTvFullWindow,
          onPressed: () {
            _onHover();
            ref.read(liveTvViewModeProvider.notifier).state = isFullWindow
                ? LiveTvViewMode.split
                : LiveTvViewMode.fullWindow;
          },
        ),
        // Fullscreen
        FullscreenButton(
          isFullscreen: _isFullScreen,
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
        final isAtLive =
            duration <= Duration.zero ||
            (duration - position).inSeconds.abs() < 30;

        return GestureDetector(
          onTap: isAtLive ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isAtLive ? AppTheme.favorites : Colors.white10,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isAtLive
                  ? [
                      BoxShadow(
                        color: AppTheme.favorites.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
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
                  const Icon(
                    Icons.arrow_forward,
                    size: 12,
                    color: AppTheme.favorites,
                  ),
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
