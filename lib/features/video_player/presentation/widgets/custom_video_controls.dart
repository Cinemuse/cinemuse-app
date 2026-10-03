import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:window_manager/window_manager.dart';

import 'package:cinemuse_app/core/application/display_mode_provider.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/video_top_bar.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/video_bottom_bar.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/next_episode_overlay.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/cast_device_selector.dart';
import 'package:cinemuse_app/core/presentation/widgets/buffering_indicator.dart';
import 'package:cinemuse_app/core/presentation/widgets/play_pause_overlay.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/number_input_osd.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_list_panel.dart';

enum DragType { none, volume, brightness }

class CustomVideoControls extends ConsumerStatefulWidget {
  final VideoState videoState;
  final CinemaPlayerState playerState;
  final PlayerParams params;
  final VoidCallback onSettingsPressed;
  final VoidCallback? onBackPressed;
  final ValueChanged<SliderOverlayType>? onOverlayRequested;
  final VoidCallback? onNextEpisode;
  final Channel? channel;
  final bool isLive;
  final ValueChanged<String>? onNumberInput;
  final VoidCallback? onConfirmNumber;
  final String numberBuffer;
  final VoidCallback? onNextChannel;
  final VoidCallback? onPreviousChannel;
  final VoidCallback? onOpenChannelGuide;
  final bool isFullWindow;
  final VoidCallback? onToggleFullWindow;

  const CustomVideoControls({
    super.key,
    required this.videoState,
    required this.playerState,
    required this.params,
    required this.onSettingsPressed,
    this.onBackPressed,
    this.onOverlayRequested,
    this.onNextEpisode,
    this.channel,
    this.isLive = false,
    this.onNumberInput,
    this.onConfirmNumber,
    this.numberBuffer = '',
    this.onNextChannel,
    this.onPreviousChannel,
    this.onOpenChannelGuide,
    this.isFullWindow = false,
    this.onToggleFullWindow,
  });

  @override
  ConsumerState<CustomVideoControls> createState() =>
      _CustomVideoControlsState();
}

class _CustomVideoControlsState extends ConsumerState<CustomVideoControls> {
  final FocusNode _rootFocusNode = FocusNode(debugLabel: 'CustomVideoControlsRoot');
  final FocusNode _playPauseFocusNode = FocusNode(debugLabel: 'PlayPauseTvButton');
  final FocusNode _seekbarFocusNode = FocusNode(debugLabel: 'SeekbarFocusNode');

  bool _visible = true;
  Timer? _hideTimer;
  bool _dragging = false;
  double _lastVolume = 100.0;
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

  DateTime? _lastHiddenSkipTime;
  Timer? _numberInputTimer;

  /// Tracks whether the window was already maximized before we entered
  /// fullscreen, so we can restore the original state on exit.
  static bool _wasMaximizedBeforeFullscreen = false;
  static Rect? _previousBounds;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
    _initFullscreenState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncFocusForVisibility();
    });
  }

  void _initFullscreenState() {
    if (mounted) setState(() => _isFullScreen = _isFullscreenSafe());
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _clearVirtualPositionTimer?.cancel();
    _hideIndicatorTimer?.cancel();
    _seekIndicatorTimer?.cancel();
    _numberInputTimer?.cancel();
    _rootFocusNode.dispose();
    _playPauseFocusNode.dispose();
    _seekbarFocusNode.dispose();
    super.dispose();
  }

  void _syncFocusForVisibility() {
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
      _hideTimer?.cancel();
      _syncFocusForVisibility();
    }
  }

  void _onHover() {
    _showControls();
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
    if (widget.onBackPressed != null) {
      if (mounted) widget.onBackPressed!();
    }
  }

  void _zapNextChannel() {
    if (widget.onNextChannel != null) {
      widget.onNextChannel!();
      return;
    }
    final channels = ref.read(filteredChannelsProvider).valueOrNull ??
        ref.read(channelsProvider).valueOrNull ??
        [];
    if (channels.isEmpty) return;
    final current = widget.channel ?? ref.read(selectedChannelProvider);
    final idx = channels.indexWhere((c) => c.uniqueId == current?.uniqueId);
    final nextIdx = idx == -1 ? 0 : (idx + 1) % channels.length;
    ref.read(selectedChannelProvider.notifier).state = channels[nextIdx];
  }

  void _zapPreviousChannel() {
    if (widget.onPreviousChannel != null) {
      widget.onPreviousChannel!();
      return;
    }
    final channels = ref.read(filteredChannelsProvider).valueOrNull ??
        ref.read(channelsProvider).valueOrNull ??
        [];
    if (channels.isEmpty) return;
    final current = widget.channel ?? ref.read(selectedChannelProvider);
    final idx = channels.indexWhere((c) => c.uniqueId == current?.uniqueId);
    final prevIdx =
        idx == -1 ? 0 : (idx - 1 + channels.length) % channels.length;
    ref.read(selectedChannelProvider.notifier).state = channels[prevIdx];
  }

  void _handleNumberInput(String digit) {
    if (widget.onNumberInput != null) {
      widget.onNumberInput!(digit);
      return;
    }
    final buffer = ref.read(numberInputBufferProvider);
    ref.read(numberInputBufferProvider.notifier).state = buffer + digit;
    _numberInputTimer?.cancel();
    _numberInputTimer = Timer(const Duration(seconds: 2), () {
      _confirmNumberInput();
    });
  }

  void _confirmNumberInput() {
    if (widget.onConfirmNumber != null) {
      widget.onConfirmNumber!();
      return;
    }
    _numberInputTimer?.cancel();
    final buffer = ref.read(numberInputBufferProvider);
    if (buffer.isEmpty) return;

    final lcn = int.tryParse(buffer);
    if (lcn != null) {
      final channels = ref.read(channelsProvider).valueOrNull ?? [];
      final match = channels.where((c) => c.lcn == lcn).firstOrNull;
      if (match != null) {
        ref.read(selectedChannelProvider.notifier).state = match;
      }
    }
    ref.read(numberInputBufferProvider.notifier).state = '';
  }

  Widget _buildChannelOverlayDrawer() {
    final isOverlayOpen = ref.watch(liveTvChannelOverlayProvider);
    if (!isOverlayOpen) return const SizedBox.shrink();

    void closeOverlayAndReturnToControls() {
      ref.read(liveTvChannelOverlayProvider.notifier).state = false;
      _showControls();
      _playPauseFocusNode.requestFocus();
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: closeOverlayAndReturnToControls,
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 380,
          child: RepaintBoundary(
            child: FocusScope(
              autofocus: true,
              child: ChannelListPanel(
                isOverlay: true,
                onClose: closeOverlayAndReturnToControls,
              ),
            ),
          ),
        ),
      ],
    );
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final isLive = widget.isLive || widget.params.type == 'livetv';

    // Channel drawer overlay handling: overlay navigation is completely self-contained.
    // Do not process any background keys (playback, shortcuts, number input, etc.)
    final isOverlayOpen = ref.read(liveTvChannelOverlayProvider);
    if (isOverlayOpen) {
      return KeyEventResult.ignored;
    }

    // Direct channel number input (0-9)
    if (isLive) {
      final keyLabel = key.keyLabel;
      if (keyLabel.length == 1 && int.tryParse(keyLabel) != null) {
        if (event is KeyDownEvent) {
          _handleNumberInput(keyLabel);
        }
        _onHover();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        final buffer = widget.numberBuffer.isNotEmpty
            ? widget.numberBuffer
            : ref.read(numberInputBufferProvider);
        if (buffer.isNotEmpty) {
          if (event is KeyDownEvent) {
            _confirmNumberInput();
          }
          return KeyEventResult.handled;
        }
      }
    }

    final mediaResult = _handleMediaKeys(event, key);
    if (mediaResult != KeyEventResult.ignored) return mediaResult;

    final player = widget.playerState.controller.player;
    if (!_visible) {
      return _handleHiddenControlsKeys(event, key, player);
    }

    final isBigPicture = ref.read(isBigPictureProvider);
    return _handleVisibleControlsKeys(event, key, player, isBigPicture);
  }

  KeyEventResult _handleMediaKeys(KeyEvent event, LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.mediaPlay ||
        key == LogicalKeyboardKey.mediaPause) {
      if (event is KeyDownEvent) _togglePlayPause();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaFastForward) {
      _performRealSkip(true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaRewind) {
      _performRealSkip(false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleHiddenControlsKeys(
    KeyEvent event,
    LogicalKeyboardKey key,
    Player player,
  ) {
    final isLive = widget.isLive || widget.params.type == 'livetv';

    if (key == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) _togglePlayPause();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA) {
      if (event is KeyDownEvent) {
        _showControls();
        _playPauseFocusNode.requestFocus();
      }
      return KeyEventResult.handled;
    }

    // Up / Down / Channel Up / Channel Down / Page Up / Page Down:
    // Live TV: Zaps channels!
    // VOD: Unused!
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.channelUp ||
        key == LogicalKeyboardKey.channelDown ||
        key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.pageDown) {
      if (isLive) {
        if (event is KeyDownEvent) {
          final isUp = key == LogicalKeyboardKey.arrowUp ||
              key == LogicalKeyboardKey.channelUp ||
              key == LogicalKeyboardKey.pageUp;
          if (isUp) {
            _zapPreviousChannel();
          } else {
            _zapNextChannel();
          }
        }
        return KeyEventResult.handled;
      }
      // VOD player: Up/Down are unused when controls are hidden
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (isLive) {
        if (event is KeyDownEvent) {
          final isFullOrStandalone = widget.isFullWindow ||
              widget.params.type == 'livetv' ||
              ref.read(liveTvViewModeProvider) == LiveTvViewMode.fullWindow ||
              _isFullScreen;
          if (isFullOrStandalone) {
            ref.read(liveTvChannelOverlayProvider.notifier).state = true;
          }
        }
        return KeyEventResult.handled;
      }
      final now = DateTime.now();
      if (event is KeyRepeatEvent) {
        if (_lastHiddenSkipTime != null &&
            now.difference(_lastHiddenSkipTime!).inMilliseconds < 110) {
          return KeyEventResult.handled;
        }
      }
      _lastHiddenSkipTime = now;
      _performRealSkip(false, showControls: false);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      if (isLive) {
        return KeyEventResult.handled;
      }
      final now = DateTime.now();
      if (event is KeyRepeatEvent) {
        if (_lastHiddenSkipTime != null &&
            now.difference(_lastHiddenSkipTime!).inMilliseconds < 110) {
          return KeyEventResult.handled;
        }
      }
      _lastHiddenSkipTime = now;
      _performRealSkip(true, showControls: false);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.goBack) {
      if (event is KeyDownEvent) _handleBack();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF || key == LogicalKeyboardKey.f11) {
      if (event is KeyDownEvent) _toggleFullscreen();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyM) {
      if (event is KeyDownEvent) _toggleMute();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleVisibleControlsKeys(
    KeyEvent event,
    LogicalKeyboardKey key,
    Player player,
    bool isBigPicture,
  ) {
    _startHideTimer();

    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.goBack) {
      if (event is KeyDownEvent) {
        if (_isFullscreenSafe() && !isBigPicture) {
          _toggleFullscreen();
        } else {
          _hideControls();
        }
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) _togglePlayPause();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyM) {
      if (event is KeyDownEvent) _toggleMute();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF || key == LogicalKeyboardKey.f11) {
      if (event is KeyDownEvent) _toggleFullscreen();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyQ) {
      if (event is KeyDownEvent) _handleBack();
      return KeyEventResult.handled;
    }

    // Directional navigation (Left/Right/Up/Down) is delegated to the focused
    // control button or seekbar so buttons can be traversed without skipping video.
    return KeyEventResult.ignored;
  }

  void _performRealSkip(bool forward, {bool showControls = true}) {
    _showSeekFeedback(forward);
    final player = widget.playerState.controller.player;
    final currentPos = _virtualPosition ?? player.state.position;
    final duration = player.state.duration;
    final target = Duration(
      seconds: (currentPos.inSeconds + (forward ? 10 : -10)).clamp(
        0,
        duration.inSeconds,
      ),
    );
    setState(() => _virtualPosition = target);
    ref.read(playerControllerProvider(widget.params).notifier).seek(target);
    _clearVirtualPositionTimer?.cancel();
    _clearVirtualPositionTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _virtualPosition = null);
      }
    });
    if (showControls) {
      _onHover();
    }
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
    final isBigPicture = ref.watch(isBigPictureProvider);
    final isOverlayOpen = ref.watch(liveTvChannelOverlayProvider);

    final isLive = widget.isLive || widget.params.type == 'livetv';

    return Focus(
      focusNode: _rootFocusNode,
      autofocus: true,
      canRequestFocus: (!isBigPicture || !_visible) && !isOverlayOpen,
      onKeyEvent: (node, event) => _handleKeyEvent(event),
      child: MouseRegion(
        onHover: (_) => _onHover(),
        cursor: (_visible || !_isFullScreen)
            ? SystemMouseCursors.basic
            : SystemMouseCursors.none,
        child: GestureDetector(
          onTap: () {
            if (isOverlayOpen) return;
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
              ExcludeFocus(
                excluding: isOverlayOpen,
                child: AnimatedOpacity(
                  opacity: _visible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: ExcludeFocus(
                        excluding: isBigPicture,
                        child: (!_isFullScreen &&
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
                                  channel: widget.channel,
                                  isLive: isLive,
                                ),
                              )
                            : VideoTopBar(
                                playerState: widget.playerState,
                                params: widget.params,
                                onSettingsPressed: widget.onSettingsPressed,
                                onCastPressed: () =>
                                    _handleCastPressed(context),
                                onBackPressed: _handleBack,
                                channel: widget.channel,
                                isLive: isLive,
                              ),
                      ),
                    ),

                    // Buffering / play-pause center overlay
                    BufferingIndicator(player: player),
                    PlayPauseOverlay(
                      player: player,
                      visible: _visible,
                      onTogglePlayPause: _togglePlayPause,
                      onSkip: _performRealSkip,
                      seekAmount: _seekAmount,
                      showSeekIndicator: _showSeekIndicator,
                    ),

                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: ExcludeFocus(
                        excluding: !_visible,
                        child: VideoBottomBar(
                          playerState: widget.playerState,
                          virtualPosition: _virtualPosition,
                          dragging: _dragging,
                          isLive: isLive,
                          onPreviousChannel: _zapPreviousChannel,
                          onNextChannel: _zapNextChannel,
                          onOpenChannelGuide: () {
                            ref
                                .read(liveTvChannelOverlayProvider.notifier)
                                .state = true;
                          },
                          onChangeStart: (value) {
                            setState(() {
                              _dragging = true;
                              _virtualPosition =
                                  Duration(seconds: value.toInt());
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
                                if (mounted) {
                                  setState(() => _virtualPosition = null);
                                }
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
                          onStopPressed: _handleBack,
                          isFullscreen: _isFullScreen,
                          onToggleFullscreen: _toggleFullscreen,
                          onNextEpisode: widget.onNextEpisode,
                          onSettingsPressed: () {
                            _hideTimer?.cancel();
                            widget.onSettingsPressed();
                          },
                          playPauseFocusNode: _playPauseFocusNode,
                          seekbarFocusNode: _seekbarFocusNode,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

              // Number input OSD (always visible, above controls)
              Consumer(
                builder: (context, ref, _) {
                  final buffer = widget.numberBuffer.isNotEmpty
                      ? widget.numberBuffer
                      : ref.watch(numberInputBufferProvider);
                  if (buffer.isEmpty) return const SizedBox.shrink();
                  return NumberInputOsd(buffer: buffer);
                },
              ),

              // Channel List Overlay Drawer (for Live TV)
              if (isLive) _buildChannelOverlayDrawer(),

              // Center Seek Indicator HUD (sleek modern frosted badge)
              if (_showSeekIndicator)
                Center(
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.85, end: 1.0),
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: child,
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                                width: 1,
                              ),
                              boxShadow: AppTheme.shadowNeonSm,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _seekAmount > 0
                                      ? Icons.fast_forward_rounded
                                      : Icons.fast_rewind_rounded,
                                  color: AppTheme.textWhite,
                                  size: 26,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _seekAmount > 0
                                      ? '+${_seekAmount}s'
                                      : '${_seekAmount}s',
                                  style: const TextStyle(
                                    color: AppTheme.textWhite,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Top-Center Volume & Brightness Indicator HUD (modern floating frosted capsule)
              if (_currentDragType != DragType.none)
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 36.0),
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                                width: 1,
                              ),
                              boxShadow: AppTheme.shadowNeonSm,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _currentDragType == DragType.brightness
                                      ? Icons.brightness_6_rounded
                                      : (_dragIndicatorValue <= 0
                                          ? Icons.volume_off_rounded
                                          : Icons.volume_up_rounded),
                                  color: AppTheme.textWhite,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 90,
                                  height: 4,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: _dragIndicatorValue,
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.18),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                        AppTheme.textWhite,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${((_dragIndicatorValue) * 100).round()}%',
                                  style: TextStyle(
                                    color: AppTheme.textWhite
                                        .withValues(alpha: 0.8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
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
