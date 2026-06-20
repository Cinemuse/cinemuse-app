import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Centered play icon shown when the player is paused and controls are visible.
/// On mobile, this shows the main playback controls (Play/Pause, Skip).
class PlayPauseOverlay extends StatelessWidget {
  final Player player;
  final bool visible;
  final VoidCallback onTogglePlayPause;
  final Function(bool) onSkip;
  final int seekAmount;
  final bool showSeekIndicator;

  const PlayPauseOverlay({
    super.key,
    required this.player,
    required this.visible,
    required this.onTogglePlayPause,
    required this.onSkip,
    this.seekAmount = 0,
    this.showSeekIndicator = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    return Center(
      child: StreamBuilder<bool>(
        stream: player.stream.playing,
        initialData: player.state.playing,
        builder: (context, snapshot) {
          final isPlaying = snapshot.data ?? player.state.playing;

          if (isMobile) {
            return IgnorePointer(
              ignoring: !visible,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SeekButton(
                    isForward: false,
                    isActive: showSeekIndicator && seekAmount < 0,
                    seekAmount: seekAmount,
                    onSkip: () => onSkip(false),
                  ),
                  const SizedBox(width: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                      iconSize: 48,
                      onPressed: onTogglePlayPause,
                    ),
                  ),
                  const SizedBox(width: 24),
                  _SeekButton(
                    isForward: true,
                    isActive: showSeekIndicator && seekAmount > 0,
                    seekAmount: seekAmount,
                    onSkip: () => onSkip(true),
                  ),
                ],
              ),
            );
          }

          // Desktop behavior
          if (!isPlaying && visible) {
            return IgnorePointer(
              ignoring: true,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _SeekButton extends StatelessWidget {
  final bool isForward;
  final bool isActive;
  final int seekAmount;
  final VoidCallback onSkip;

  const _SeekButton({
    required this.isForward,
    required this.isActive,
    required this.seekAmount,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: onSkip,
        child: Container(
          width: 80,
          height: 80,
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1.0).animate(animation),
                child: child,
              ),
            ),
            child: isActive
                ? Column(
                    key: const ValueKey('active'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isForward
                            ? Icons.fast_forward_rounded
                            : Icons.fast_rewind_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isForward ? '+${seekAmount}s' : '${seekAmount}s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                : Icon(
                    isForward
                        ? Icons.forward_10_rounded
                        : Icons.replay_10_rounded,
                    key: const ValueKey('inactive'),
                    color: Colors.white,
                    size: 48,
                  ),
          ),
        ),
      ),
    );
  }
}
