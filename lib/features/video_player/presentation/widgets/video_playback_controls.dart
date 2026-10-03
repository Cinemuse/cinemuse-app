import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/application/l10n_provider.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:media_kit/media_kit.dart';

/// Bottom-row playback controls for the VOD video player.
class VideoPlaybackControls extends ConsumerStatefulWidget {
  final CinemaPlayerState playerState;
  final VoidCallback onTogglePlayPause;
  final Function(bool) onSkip;
  final VoidCallback onToggleMute;
  final VoidCallback onStopPressed;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onSettingsPressed;
  final FocusNode? playPauseFocusNode;
  final FocusNode? seekbarFocusNode;
  final bool isLive;
  final VoidCallback? onPreviousChannel;
  final VoidCallback? onNextChannel;
  final VoidCallback? onOpenChannelGuide;

  const VideoPlaybackControls({
    super.key,
    required this.playerState,
    required this.onTogglePlayPause,
    required this.onSkip,
    required this.onToggleMute,
    required this.onStopPressed,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    this.onNextEpisode,
    this.onSettingsPressed,
    this.playPauseFocusNode,
    this.seekbarFocusNode,
    this.isLive = false,
    this.onPreviousChannel,
    this.onNextChannel,
    this.onOpenChannelGuide,
  });

  @override
  ConsumerState<VideoPlaybackControls> createState() =>
      _VideoPlaybackControlsState();
}

class _VideoPlaybackControlsState
    extends ConsumerState<VideoPlaybackControls> {
  late final FocusNode _stopFocusNode;
  late final FocusNode _rewindFocusNode;
  late final FocusNode _forwardFocusNode;
  late final FocusNode _settingsFocusNode;
  late final FocusNode _nextEpisodeFocusNode;
  late final FocusNode _fullscreenFocusNode;
  late final FocusNode _prevChannelFocusNode;
  late final FocusNode _nextChannelFocusNode;
  late final FocusNode _channelGuideFocusNode;
  FocusNode? _internalPlayPauseFocusNode;

  FocusNode get _effectivePlayPauseFocusNode =>
      widget.playPauseFocusNode ??
      (_internalPlayPauseFocusNode ??=
          FocusNode(debugLabel: 'PlayPauseTvButton'));

  @override
  void initState() {
    super.initState();
    _stopFocusNode = FocusNode(debugLabel: 'StopTvButton');
    _rewindFocusNode = FocusNode(debugLabel: 'RewindTvButton');
    _forwardFocusNode = FocusNode(debugLabel: 'ForwardTvButton');
    _settingsFocusNode = FocusNode(debugLabel: 'SettingsTvButton');
    _nextEpisodeFocusNode = FocusNode(debugLabel: 'NextEpisodeTvButton');
    _fullscreenFocusNode = FocusNode(debugLabel: 'FullscreenTvButton');
    _prevChannelFocusNode = FocusNode(debugLabel: 'PrevChannelTvButton');
    _nextChannelFocusNode = FocusNode(debugLabel: 'NextChannelTvButton');
    _channelGuideFocusNode = FocusNode(debugLabel: 'ChannelGuideTvButton');
  }

  @override
  void dispose() {
    _stopFocusNode.dispose();
    _rewindFocusNode.dispose();
    _forwardFocusNode.dispose();
    _settingsFocusNode.dispose();
    _nextEpisodeFocusNode.dispose();
    _fullscreenFocusNode.dispose();
    _prevChannelFocusNode.dispose();
    _nextChannelFocusNode.dispose();
    _channelGuideFocusNode.dispose();
    _internalPlayPauseFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.playerState.controller.player;
    final l10n = ref.watch(localizationsProvider);

    final hasSettings = widget.onSettingsPressed != null;
    final hasNext = widget.onNextEpisode != null;
    final hasGuide = widget.onOpenChannelGuide != null;

    if (widget.isLive) {
      final rightStartNode = hasGuide
          ? _channelGuideFocusNode
          : (hasSettings ? _settingsFocusNode : _fullscreenFocusNode);
      final guideNextNode =
          hasSettings ? _settingsFocusNode : _fullscreenFocusNode;
      final settingsPrevNode =
          hasGuide ? _channelGuideFocusNode : _nextChannelFocusNode;
      final fullscreenPrevNode = hasSettings
          ? _settingsFocusNode
          : (hasGuide ? _channelGuideFocusNode : _nextChannelFocusNode);

      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            _buildControlButton(
              icon: Icons.skip_previous_rounded,
              tooltip: l10n.playerPreviousChannel,
              focusNode: _prevChannelFocusNode,
              onKeyEvent: (node, event) => _handleKey(
                event,
                prev: null,
                next: _effectivePlayPauseFocusNode,
              ),
              onTap: widget.onPreviousChannel ?? () {},
            ),
            const SizedBox(width: 4),
            _buildPlayPauseButton(player, l10n),
            const SizedBox(width: 4),
            _buildControlButton(
              icon: Icons.stop_rounded,
              tooltip: l10n.playerStop,
              focusNode: _stopFocusNode,
              onKeyEvent: (node, event) => _handleKey(
                event,
                prev: _effectivePlayPauseFocusNode,
                next: _nextChannelFocusNode,
              ),
              onTap: widget.onStopPressed,
            ),
            const SizedBox(width: 4),
            _buildControlButton(
              icon: Icons.skip_next_rounded,
              tooltip: l10n.playerNextChannel,
              focusNode: _nextChannelFocusNode,
              onKeyEvent: (node, event) => _handleKey(
                event,
                prev: _stopFocusNode,
                next: rightStartNode,
              ),
              onTap: widget.onNextChannel ?? () {},
            ),
            const Spacer(),
            if (hasGuide) ...[
              _buildControlButton(
                icon: Icons.list_rounded,
                tooltip: l10n.playerChannelList,
                focusNode: _channelGuideFocusNode,
                onKeyEvent: (node, event) => _handleKey(
                  event,
                  prev: _nextChannelFocusNode,
                  next: guideNextNode,
                ),
                onTap: widget.onOpenChannelGuide!,
              ),
              const SizedBox(width: 4),
            ],
            if (hasSettings) ...[
              _buildControlButton(
                icon: Icons.tune_rounded,
                tooltip: l10n.playerSettings,
                focusNode: _settingsFocusNode,
                onKeyEvent: (node, event) => _handleKey(
                  event,
                  prev: settingsPrevNode,
                  next: _fullscreenFocusNode,
                ),
                onTap: widget.onSettingsPressed!,
              ),
              const SizedBox(width: 4),
            ],
            _buildFullscreenButton(
              l10n,
              fullscreenPrevNode,
            ),
          ],
        ),
      );
    }

    final forwardNextNode = hasSettings
        ? _settingsFocusNode
        : (hasNext ? _nextEpisodeFocusNode : _fullscreenFocusNode);
    final settingsNextNode =
        hasNext ? _nextEpisodeFocusNode : _fullscreenFocusNode;
    final nextPrevNode =
        hasSettings ? _settingsFocusNode : _forwardFocusNode;
    final fullscreenPrevNode = hasNext
        ? _nextEpisodeFocusNode
        : (hasSettings ? _settingsFocusNode : _forwardFocusNode);

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          _buildControlButton(
            icon: Icons.replay_10_rounded,
            tooltip: l10n.playerSkipBackward,
            focusNode: _rewindFocusNode,
            onKeyEvent: (node, event) => _handleKey(
              event,
              prev: null,
              next: _effectivePlayPauseFocusNode,
            ),
            onTap: () => widget.onSkip(false),
          ),
          const SizedBox(width: 4),
          _buildPlayPauseButton(player, l10n),
          const SizedBox(width: 4),
          _buildControlButton(
            icon: Icons.stop_rounded,
            tooltip: l10n.playerStop,
            focusNode: _stopFocusNode,
            onKeyEvent: (node, event) => _handleKey(
              event,
              prev: _effectivePlayPauseFocusNode,
              next: _forwardFocusNode,
            ),
            onTap: widget.onStopPressed,
          ),
          const SizedBox(width: 4),
          _buildControlButton(
            icon: Icons.forward_10_rounded,
            tooltip: l10n.playerSkipForward,
            focusNode: _forwardFocusNode,
            onKeyEvent: (node, event) => _handleKey(
              event,
              prev: _stopFocusNode,
              next: forwardNextNode,
            ),
            onTap: () => widget.onSkip(true),
          ),
          const Spacer(),
          if (hasSettings) ...[
            _buildControlButton(
              icon: Icons.tune_rounded,
              tooltip: l10n.playerSettings,
              focusNode: _settingsFocusNode,
              onKeyEvent: (node, event) => _handleKey(
                event,
                prev: _forwardFocusNode,
                next: settingsNextNode,
              ),
              onTap: widget.onSettingsPressed!,
            ),
            const SizedBox(width: 4),
          ],
          if (hasNext) ...[
            _buildControlButton(
              icon: Icons.skip_next_rounded,
              tooltip: l10n.playerNextEpisode,
              focusNode: _nextEpisodeFocusNode,
              onKeyEvent: (node, event) => _handleKey(
                event,
                prev: nextPrevNode,
                next: _fullscreenFocusNode,
              ),
              onTap: widget.onNextEpisode!,
            ),
            const SizedBox(width: 4),
          ],
          _buildFullscreenButton(l10n, fullscreenPrevNode),
        ],
      ),
    );
  }

  KeyEventResult _handleKey(
    KeyEvent event, {
    FocusNode? prev,
    FocusNode? next,
  }) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (event is KeyDownEvent && prev != null) {
        prev.requestFocus();
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (event is KeyDownEvent && next != null) {
        next.requestFocus();
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (event is KeyDownEvent && widget.seekbarFocusNode != null) {
        widget.seekbarFocusNode!.requestFocus();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Widget _buildPlayPauseButton(Player player, AppLocalizations l10n) {
    final prevNode = widget.isLive ? _prevChannelFocusNode : _rewindFocusNode;
    final nextNode = _stopFocusNode;
    return StreamBuilder<bool>(
      stream: player.stream.playing,
      initialData: player.state.playing,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data ?? player.state.playing;
        return _buildControlButton(
          icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          tooltip: isPlaying ? l10n.playerPause : l10n.playerPlay,
          focusNode: _effectivePlayPauseFocusNode,
          autofocus: true,
          iconSize: 28,
          buttonSize: 42,
          onKeyEvent: (node, event) => _handleKey(
            event,
            prev: prevNode,
            next: nextNode,
          ),
          onTap: widget.onTogglePlayPause,
        );
      },
    );
  }

  Widget _buildFullscreenButton(
    AppLocalizations l10n,
    FocusNode? prevNode, {
    FocusNode? nextNode,
  }) {
    return _buildControlButton(
      icon: widget.isFullscreen
          ? Icons.fullscreen_exit_rounded
          : Icons.fullscreen_rounded,
      tooltip: widget.isFullscreen
          ? l10n.playerExitFullscreen
          : l10n.playerFullscreen,
      focusNode: _fullscreenFocusNode,
      iconSize: 26,
      buttonSize: 40,
      onKeyEvent: (node, event) => _handleKey(
        event,
        prev: prevNode,
        next: nextNode,
      ),
      onTap: widget.onToggleFullscreen,
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    FocusNode? focusNode,
    FocusOnKeyEventCallback? onKeyEvent,
    bool autofocus = false,
    double iconSize = 24,
    double buttonSize = 40,
  }) {
    return DpadFocusable(
      focusNode: focusNode,
      onKeyEvent: onKeyEvent,
      autofocus: autofocus,
      onTap: onTap,
      scale: 1.1,
      borderRadius: BorderRadius.circular(buttonSize / 2),
      builder: (context, isFocused, isHovered, child) {
        return Tooltip(
          message: tooltip,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFocused
                  ? AppTheme.accent.withValues(alpha: 0.22)
                  : (isHovered
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.transparent),
              border: Border.all(
                color: isFocused
                    ? AppTheme.accent
                    : (isHovered
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.transparent),
                width: 1.5,
              ),
              boxShadow: isFocused ? AppTheme.shadowNeonSm : null,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: isFocused || isHovered
                  ? AppTheme.textWhite
                  : AppTheme.textWhite.withValues(alpha: 0.9),
              size: iconSize,
            ),
          ),
        );
      },
      child: const SizedBox.shrink(),
    );
  }
}
