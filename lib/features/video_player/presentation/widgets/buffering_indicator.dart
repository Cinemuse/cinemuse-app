import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';

/// Centered buffering spinner overlay for any media_kit [Player], shown only
/// while the player is meant to be playing.
///
/// media_kit's buffering flag clears only when playback moves again, so a
/// video paused while it loads (a skip, then pause) stays "buffering" over
/// a ready picture until play is pressed.
class BufferingIndicator extends StatelessWidget {
  final Player player;

  const BufferingIndicator({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: StreamBuilder<bool>(
        stream: player.stream.playing,
        initialData: player.state.playing,
        builder: (context, playing) => StreamBuilder<bool>(
          stream: player.stream.buffering,
          initialData: player.state.buffering,
          builder: (context, buffering) {
            if (playing.data == true && buffering.data == true) {
              return const CircularProgressIndicator(color: AppTheme.accent);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
