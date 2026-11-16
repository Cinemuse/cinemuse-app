import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';

/// Playback progress bar for poster and backdrop cards. Place it inside the
/// card's [Stack]. At 0 it shows the empty track (not started yet).
class CardProgressBar extends StatelessWidget {
  /// Playback progress from 0.0 to 1.0 (clamped).
  final double progress;

  const CardProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    // Inset from the edges on a dark track: on the edge, the accent-coloured
    // focus border drew over it and hid it.
    return Positioned(
      left: 8,
      right: 8,
      bottom: 8,
      child: ClipRRect(
        borderRadius: AppTheme.radiusFull,
        child: LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          minHeight: 4,
          backgroundColor: Colors.black54,
          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
        ),
      ),
    );
  }
}
