import 'package:flutter/widgets.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/player_settings_panel.dart';

/// Bundles all user interaction callbacks and focus targets for the video player's
/// playback controls, eliminating prop-drilling between controls, bottom bar, and buttons.
class PlaybackControlActions {
  final VoidCallback onTogglePlayPause;
  final void Function(bool forward) onSkip;
  final VoidCallback onToggleMute;
  final VoidCallback onStopPressed;
  final bool isFullscreen;

  /// Null hides the full-screen button: the app already fills the screen
  /// (a TV, or the app's own full screen on a computer).
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onNextEpisode;

  /// The Source button, and on films the Tracks button.
  final ValueChanged<PlayerSettingsKind>? onSettingsPressed;
  final FocusNode? playPauseFocusNode;
  final FocusNode? seekbarFocusNode;
  final bool isLive;
  final VoidCallback? onPreviousChannel;
  final VoidCallback? onNextChannel;
  final VoidCallback? onOpenChannelGuide;

  /// The channel list button, focused again when the list closes.
  final FocusNode? channelListFocusNode;
  final VoidCallback? onResetHideTimer;

  const PlaybackControlActions({
    required this.onTogglePlayPause,
    required this.onSkip,
    required this.onToggleMute,
    required this.onStopPressed,
    required this.isFullscreen,
    this.onToggleFullscreen,
    this.onNextEpisode,
    this.onSettingsPressed,
    this.playPauseFocusNode,
    this.seekbarFocusNode,
    this.isLive = false,
    this.onPreviousChannel,
    this.onNextChannel,
    this.onOpenChannelGuide,
    this.channelListFocusNode,
    this.onResetHideTimer,
  });
}
