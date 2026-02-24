import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

/// Centered play icon shown when the player is paused and controls are visible.
class PlayPauseOverlay extends StatelessWidget {
  final Player player;
  final bool visible;

  const PlayPauseOverlay({
    super.key,
    required this.player,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: StreamBuilder<bool>(
        stream: player.stream.playing,
        initialData: player.state.playing,
        builder: (context, snapshot) {
          final isPlaying = snapshot.data ?? player.state.playing;
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
