import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';

/// Centered buffering spinner overlay for any media_kit [Player].
class BufferingIndicator extends StatelessWidget {
  final Player player;

  const BufferingIndicator({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: StreamBuilder<bool>(
        stream: player.stream.buffering,
        initialData: player.state.buffering,
        builder: (context, snapshot) {
          if (snapshot.data == true) {
            return const CircularProgressIndicator(color: AppTheme.accent);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
