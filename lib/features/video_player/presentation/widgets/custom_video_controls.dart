import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'dart:io' show Platform;
import 'package:window_manager/window_manager.dart' show DragToMoveArea;
import 'package:cinemuse_app/features/video_player/presentation/widgets/video_top_bar.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/video_bottom_bar.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/next_episode_overlay.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/overlays/seek_feedback_hud.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/overlays/volume_brightness_hud.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/overlays/live_tv_channel_drawer.dart';
import 'package:cinemuse_app/features/video_player/presentation/helpers/player_window_coordinator.dart';
import 'package:cinemuse_app/features/video_player/presentation/helpers/controls_key_handler.dart';
import 'package:cinemuse_app/features/video_player/presentation/helpers/player_channel_input_coordinator.dart';
import 'package:cinemuse_app/features/video_player/presentation/helpers/controls_gesture_coordinator.dart';
import 'package:cinemuse_app/features/video_player/presentation/helpers/player_seek_coordinator.dart';
import 'package:cinemuse_app/features/video_player/presentation/helpers/playback_control_actions.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/buffering_indicator.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/play_pause_overlay.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/number_input_osd.dart';

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

  /// Replaces the tap's show-controls / play-pause; the Live TV mini-player
  /// opens the big player with it (REV-156).
  final VoidCallback? onTap;

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
    this.onTap,
  });

  @override
  ConsumerState<CustomVideoControls> createState() =>
      _CustomVideoControlsState();
}

class _CustomVideoControlsState extends ConsumerState<CustomVideoControls> {
  final FocusNode _rootFocusNode = FocusNode(
    debugLabel: 'CustomVideoControlsRoot',
  );
  final FocusNode _playPauseFocusNode = FocusNode(
    debugLabel: 'PlayPauseTvButton',
  );
  final FocusNode _seekbarFocusNode = FocusNode(debugLabel: 'SeekbarFocusNode');

  bool _visible = true;
  Timer? _hideTimer;
  double _lastVolume = 100.0;
  bool _isFullScreen = false;

  final ControlsKeyHandler _keyHandler = ControlsKeyHandler();
  final PlayerChannelInputCoordinator _channelCoordinator =
      PlayerChannelInputCoordinator();
  final ControlsGestureCoordinator _gestureCoordinator =
      ControlsGestureCoordinator();
  final PlayerSeekCoordinator _seekCoordinator = PlayerSeekCoordinator();

  @override
  void initState() {
    super.initState();
    _startHideTimer();
    _initFullscreenState();
    FocusManager.instance.addListener(_onGlobalFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncFocusForVisibility();
    });
  }

  void _initFullscreenState() {
    if (mounted) {
      setState(
        () => _isFullScreen = PlayerWindowCoordinator.isFullscreenSafe(
          widget.videoState,
        ),
      );
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onGlobalFocusChanged);
    _hideTimer?.cancel();
    _seekCoordinator.dispose();
    _gestureCoordinator.dispose();
    _channelCoordinator.dispose();
    _rootFocusNode.dispose();
    _playPauseFocusNode.dispose();
    _seekbarFocusNode.dispose();
    super.dispose();
  }

  void _onGlobalFocusChanged() {
    if (!mounted || !_visible) return;
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null &&
        (primary == _rootFocusNode ||
            primary.ancestors.contains(_rootFocusNode))) {
      _startHideTimer();
    }
  }

  void _syncFocusForVisibility() {
    final targetNode = _visible ? _playPauseFocusNode : _rootFocusNode;
    targetNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) targetNode.requestFocus();
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted &&
          !_seekCoordinator.dragging &&
          _gestureCoordinator.currentDragType == DragType.none &&
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

  bool _isFullscreenSafe() =>
      PlayerWindowCoordinator.isFullscreenSafe(widget.videoState);

  Future<void> _toggleFullscreen() async {
    final isNowFullscreen = await PlayerWindowCoordinator.toggleFullscreen(
      widget.videoState,
    );
    if (mounted) setState(() => _isFullScreen = isNowFullscreen);
  }

  Future<void> _handleBack() async {
    await PlayerWindowCoordinator.handleBack(
      videoState: widget.videoState,
      onBackPressed: widget.onBackPressed,
    );
    if (mounted) setState(() => _isFullScreen = false);
  }

  void _zapNextChannel() => _channelCoordinator.zapNextChannel(
    ref: ref,
    currentChannel: widget.channel,
    onCustomNextChannel: widget.onNextChannel,
  );

  void _zapPreviousChannel() => _channelCoordinator.zapPreviousChannel(
    ref: ref,
    currentChannel: widget.channel,
    onCustomPreviousChannel: widget.onPreviousChannel,
  );

  void _handleNumberInput(String digit) =>
      _channelCoordinator.handleNumberInput(
        ref: ref,
        digit: digit,
        onCustomNumberInput: widget.onNumberInput,
        onCustomConfirmNumber: widget.onConfirmNumber,
      );

  void _confirmNumberInput() => _channelCoordinator.confirmNumberInput(
    ref: ref,
    onCustomConfirmNumber: widget.onConfirmNumber,
  );

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    final isLive = widget.isLive || widget.params.type == 'livetv';
    final isOverlayOpen = ref.read(liveTvChannelOverlayProvider);
    final isFullOrStandalone =
        widget.isFullWindow ||
        widget.params.type == 'livetv' ||
        ref.read(liveTvViewModeProvider) == LiveTvViewMode.fullWindow ||
        _isFullScreen;
    final buffer = widget.numberBuffer.isNotEmpty
        ? widget.numberBuffer
        : ref.read(numberInputBufferProvider);

    return _keyHandler.handleKeyEvent(
      event: event,
      isLive: isLive,
      isOverlayOpen: isOverlayOpen,
      isVisible: _visible,
      isFullscreen: _isFullscreenSafe(),
      isFullOrStandalone: isFullOrStandalone,
      numberBuffer: buffer,
      onTogglePlayPause: _togglePlayPause,
      onSkip: _performRealSkip,
      onToggleMute: _toggleMute,
      onToggleFullscreen: _toggleFullscreen,
      onBack: _handleBack,
      onShowControls: _showControls,
      onHideControls: _hideControls,
      onFocusPlayPause: _playPauseFocusNode.requestFocus,
      onHover: _onHover,
      onNumberInput: _handleNumberInput,
      onConfirmNumber: _confirmNumberInput,
      onZapNextChannel: _zapNextChannel,
      onZapPreviousChannel: _zapPreviousChannel,
      onOpenChannelOverlay: () {
        ref.read(liveTvChannelOverlayProvider.notifier).state = true;
      },
    );
  }

  void _performRealSkip(bool forward, {bool showControls = true}) {
    _seekCoordinator.performRealSkip(
      player: widget.playerState.controller.player,
      onSeek: (target) => ref
          .read(playerControllerProvider(widget.params).notifier)
          .seek(target),
      forward: forward,
      onUpdate: () {
        if (mounted) setState(() {});
      },
      onHover: _onHover,
      showControls: showControls,
    );
  }

  void _onSeekStart(double value) => _seekCoordinator.onSeekStart(
    value: value,
    onCancelHideTimer: () => _hideTimer?.cancel(),
    onUpdate: () => mounted ? setState(() {}) : null,
  );

  void _onSeekEnd(double value) => _seekCoordinator.onSeekEnd(
    value: value,
    onSeek: (target) =>
        ref.read(playerControllerProvider(widget.params).notifier).seek(target),
    onStartHideTimer: _startHideTimer,
    onUpdate: () => mounted ? setState(() {}) : null,
  );

  void _onSeekChanged(double value) => _seekCoordinator.onSeekChanged(
    value: value,
    onUpdate: () => mounted ? setState(() {}) : null,
  );

  Widget _buildTopBar(bool isLive) {
    final isDesktopNonFullscreen =
        !_isFullScreen &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    final topBar = VideoTopBar(
      playerState: widget.playerState,
      params: widget.params,
      channel: isLive ? widget.channel : null,
      isLive: isLive,
    );

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: isDesktopNonFullscreen ? DragToMoveArea(child: topBar) : topBar,
    );
  }

  Widget _buildBottomBar(bool isLive) {
    final actions = PlaybackControlActions(
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
      isLive: isLive,
      onPreviousChannel: _zapPreviousChannel,
      onNextChannel: _zapNextChannel,
      onResetHideTimer: _startHideTimer,
    );

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ExcludeFocus(
        excluding: !_visible,
        child: VideoBottomBar(
          playerState: widget.playerState,
          virtualPosition: _seekCoordinator.virtualPosition,
          dragging: _seekCoordinator.dragging,
          onChangeStart: _onSeekStart,
          onChangeEnd: _onSeekEnd,
          onChanged: _onSeekChanged,
          actions: actions,
        ),
      ),
    );
  }

  void _onVerticalDragStart(DragStartDetails details) =>
      _gestureCoordinator.onVerticalDragStart(
        details: details,
        screenWidth: MediaQuery.of(context).size.width,
        currentVolume: widget.playerState.controller.player.state.volume,
        onHover: _onHover,
        onUpdate: () => mounted ? setState(() {}) : null,
      );

  void _onVerticalDragUpdate(DragUpdateDetails details) =>
      _gestureCoordinator.onVerticalDragUpdate(
        details: details,
        screenHeight: MediaQuery.of(context).size.height,
        currentVolume: widget.playerState.controller.player.state.volume,
        onVolumeChanged: (vol) =>
            widget.playerState.controller.player.setVolume(vol),
        onUpdate: () => mounted ? setState(() {}) : null,
      );

  void _onVerticalDragEnd(DragEndDetails details) =>
      _gestureCoordinator.onVerticalDragEnd(
        onComplete: () => mounted ? setState(() {}) : null,
        onStartHideTimer: _startHideTimer,
      );

  void _onDoubleTapDown(TapDownDetails details) =>
      _gestureCoordinator.onDoubleTapDown(details);

  void _onDoubleTap() => _gestureCoordinator.onDoubleTap(
    screenWidth: MediaQuery.of(context).size.width,
    onSkip: _performRealSkip,
  );

  void _closeChannelOverlay() {
    ref.read(liveTvChannelOverlayProvider.notifier).state = false;
    _showControls();
    _playPauseFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.playerState.controller.player;
    final isOverlayOpen = ref.watch(liveTvChannelOverlayProvider);

    final isLive = widget.isLive || widget.params.type == 'livetv';

    return Focus(
      focusNode: _rootFocusNode,
      autofocus: true,
      canRequestFocus: !isOverlayOpen,
      onKeyEvent: (node, event) => _handleKeyEvent(event),
      child: MouseRegion(
        onHover: (_) => _onHover(),
        cursor: (_visible || !_isFullScreen)
            ? SystemMouseCursors.basic
            : SystemMouseCursors.none,
        child: GestureDetector(
          onTap: () {
            if (isOverlayOpen) return;
            if (widget.onTap != null) return widget.onTap!();
            _visible ? _togglePlayPause() : _onHover();
          },
          onDoubleTapDown: _onDoubleTapDown,
          onDoubleTap: _onDoubleTap,
          onVerticalDragStart: _onVerticalDragStart,
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              IgnorePointer(
                child: Container(
                  color: Theme.of(context).colorScheme.scrim.withValues(
                    alpha: 1.0 - _gestureCoordinator.brightnessLevel,
                  ),
                ),
              ),
              ExcludeFocus(
                excluding: isOverlayOpen,
                child: AnimatedOpacity(
                  opacity: _visible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Stack(
                    children: [
                      _buildTopBar(isLive),

                      BufferingIndicator(player: player),
                      PlayPauseOverlay(
                        player: player,
                        visible: _visible,
                        onTogglePlayPause: _togglePlayPause,
                        onSkip: _performRealSkip,
                        seekAmount: _seekCoordinator.seekAmount,
                        showSeekIndicator: _seekCoordinator.showSeekIndicator,
                      ),

                      _buildBottomBar(isLive),
                    ],
                  ),
                ),
              ),

              Consumer(
                builder: (context, ref, _) {
                  final buffer = widget.numberBuffer.isNotEmpty
                      ? widget.numberBuffer
                      : ref.watch(numberInputBufferProvider);
                  return buffer.isEmpty
                      ? const SizedBox.shrink()
                      : NumberInputOsd(buffer: buffer);
                },
              ),

              if (isLive) LiveTvChannelDrawer(onClose: _closeChannelOverlay),

              if (_seekCoordinator.showSeekIndicator)
                SeekFeedbackHud(seekAmount: _seekCoordinator.seekAmount),

              if (_gestureCoordinator.currentDragType != DragType.none)
                VolumeBrightnessHud(
                  dragType: _gestureCoordinator.currentDragType,
                  indicatorValue: _gestureCoordinator.dragIndicatorValue,
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
