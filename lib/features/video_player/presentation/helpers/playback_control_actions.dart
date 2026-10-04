import 'package:flutter/widgets.dart';

/// Bundles all user interaction callbacks and focus targets for the video player's
/// playback controls, eliminating prop-drilling between controls, bottom bar, and buttons.
class PlaybackControlActions {
  final VoidCallback onTogglePlayPause;
  final void Function(bool forward) onSkip;
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
  final VoidCallback? onResetHideTimer;

  const PlaybackControlActions({
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
    this.onResetHideTimer,
  });
}
