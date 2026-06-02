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

  const PlayPauseOverlay({
    super.key,
    required this.player,
    required this.visible,
    required this.onTogglePlayPause,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

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
                  IconButton(
                    icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                    iconSize: 48,
                    onPressed: () => onSkip(false),
                  ),
                  const SizedBox(width: 32),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                      iconSize: 48,
                      onPressed: onTogglePlayPause,
                    ),
                  ),
                  const SizedBox(width: 32),
                  IconButton(
                    icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                    iconSize: 48,
                    onPressed: () => onSkip(true),
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
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
