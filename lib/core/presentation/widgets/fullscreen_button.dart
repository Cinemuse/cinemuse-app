import 'package:flutter/material.dart';

/// Shared fullscreen toggle button.
class FullscreenButton extends StatelessWidget {
  final bool isFullscreen;
  final VoidCallback onToggle;

  const FullscreenButton({
    super.key,
    required this.isFullscreen,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
        color: Colors.white,
      ),
      onPressed: onToggle,
    );
  }
}
