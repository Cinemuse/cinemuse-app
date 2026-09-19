import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/application/display_mode_provider.dart';
import 'package:cinemuse_app/core/application/l10n_provider.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/presentation/widgets/volume_control.dart';
import 'package:cinemuse_app/core/presentation/widgets/fullscreen_button.dart';
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
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onSettingsPressed;
  final FocusNode? playPauseFocusNode;

  const VideoPlaybackControls({
    super.key,
    required this.playerState,
    required this.onTogglePlayPause,
    required this.onSkip,
    required this.onToggleMute,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    this.onNextEpisode,
    this.onSettingsPressed,
    this.playPauseFocusNode,
  });

  @override
  ConsumerState<VideoPlaybackControls> createState() =>
      _VideoPlaybackControlsState();
}

class _VideoPlaybackControlsState
    extends ConsumerState<VideoPlaybackControls> {
  late final FocusNode _rewindFocusNode;
  late final FocusNode _forwardFocusNode;
  late final FocusNode _settingsFocusNode;
  late final FocusNode _nextEpisodeFocusNode;
  FocusNode? _internalPlayPauseFocusNode;

  FocusNode get _effectivePlayPauseFocusNode =>
      widget.playPauseFocusNode ??
      (_internalPlayPauseFocusNode ??= FocusNode(debugLabel: 'PlayPauseTvButton'));

  @override
  void initState() {
    super.initState();
    _rewindFocusNode = FocusNode(debugLabel: 'RewindTvButton');
    _forwardFocusNode = FocusNode(debugLabel: 'ForwardTvButton');
    _settingsFocusNode = FocusNode(debugLabel: 'SettingsTvButton');
    _nextEpisodeFocusNode = FocusNode(debugLabel: 'NextEpisodeTvButton');
  }

  @override
  void dispose() {
    _rewindFocusNode.dispose();
    _forwardFocusNode.dispose();
    _settingsFocusNode.dispose();
    _nextEpisodeFocusNode.dispose();
    _internalPlayPauseFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBigPicture = ref.watch(isBigPictureProvider);
    final player = widget.playerState.controller.player;
    final l10n = ref.watch(localizationsProvider);

    if (isBigPicture) {
      return _buildBigPictureControls(context, player, l10n);
    }

    return _buildStandardControls(context, player, l10n);
  }

  Widget _buildBigPictureControls(
    BuildContext context,
    Player player,
    AppLocalizations l10n,
  ) {
    final hasSettings = widget.onSettingsPressed != null;
    final hasNext = widget.onNextEpisode != null;

    final forwardNextNode = hasSettings
        ? _settingsFocusNode
        : (hasNext ? _nextEpisodeFocusNode : null);
    final settingsNextNode = hasNext ? _nextEpisodeFocusNode : null;
    final nextPrevNode = hasSettings ? _settingsFocusNode : _forwardFocusNode;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTvIconButton(
            icon: Icons.replay_10_rounded,
            tooltip: l10n.playerSkipBackward,
            focusNode: _rewindFocusNode,
            onKeyEvent: (node, event) =>
                _handleKey(event, prev: null, next: _effectivePlayPauseFocusNode),
            onTap: () => widget.onSkip(false),
          ),
          const SizedBox(width: 16),
          _buildPlayPauseTvButton(player),
          const SizedBox(width: 16),
          _buildTvIconButton(
            icon: Icons.forward_10_rounded,
            tooltip: l10n.playerSkipForward,
            focusNode: _forwardFocusNode,
            onKeyEvent: (node, event) => _handleKey(
              event,
              prev: _effectivePlayPauseFocusNode,
              next: forwardNextNode,
            ),
            onTap: () => widget.onSkip(true),
          ),
          if (hasSettings) ...[
            const SizedBox(width: 16),
            _buildTvIconButton(
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
          ],
          if (hasNext) ...[
            const SizedBox(width: 16),
            _buildTvIconButton(
              icon: Icons.skip_next_rounded,
              tooltip: l10n.playerNextEpisode,
              focusNode: _nextEpisodeFocusNode,
              onKeyEvent: (node, event) => _handleKey(
                event,
                prev: nextPrevNode,
                next: null,
              ),
              onTap: widget.onNextEpisode!,
            ),
          ],
        ],
      ),
    );
  }

  KeyEventResult _handleKey(
    KeyEvent event, {
    FocusNode? prev,
    FocusNode? next,
  }) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (prev != null) {
        prev.requestFocus();
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (next != null) {
        next.requestFocus();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Widget _buildPlayPauseTvButton(Player player) {
    return StreamBuilder<bool>(
      stream: player.stream.playing,
      initialData: player.state.playing,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data ?? player.state.playing;
        return _buildTvIconButton(
          icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          tooltip: isPlaying ? 'Pause' : 'Play',
          focusNode: _effectivePlayPauseFocusNode,
          autofocus: true,
          iconSize: 34,
          buttonSize: 52,
          onKeyEvent: (node, event) => _handleKey(
            event,
            prev: _rewindFocusNode,
            next: _forwardFocusNode,
          ),
          onTap: widget.onTogglePlayPause,
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
              color: Colors.white,
              size: iconSize,
            ),
          ),
        );
      },
      child: const SizedBox.shrink(),
    );
  }

  Widget _buildStandardControls(
    BuildContext context,
    Player player,
    AppLocalizations l10n,
  ) {
    final isMobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    return Row(
      children: [
        if (!isMobile) ...[
          StreamBuilder<bool>(
            stream: player.stream.playing,
            initialData: player.state.playing,
            builder: (context, snapshot) {
              final isPlaying = snapshot.data ?? player.state.playing;
              return IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: widget.onTogglePlayPause,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
            onPressed: () => widget.onSkip(false),
          ),
          IconButton(
            icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
            onPressed: () => widget.onSkip(true),
          ),
          const SizedBox(width: 4),
        ],
        VolumeControl(player: player),
        const Spacer(),
        if (widget.onNextEpisode != null)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: IconButton(
              icon: const Icon(
                Icons.skip_next_rounded,
                color: Colors.white,
                size: 28,
              ),
              onPressed: widget.onNextEpisode,
              tooltip: l10n.playerNextEpisode,
            ),
          ),
        FullscreenButton(
          isFullscreen: widget.isFullscreen,
          onToggle: widget.onToggleFullscreen,
        ),
      ],
    );
  }
}
