import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';

/// On-screen display showing the currently typed LCN number
/// for remote-style channel switching.
class NumberInputOsd extends StatelessWidget {
  final String buffer;

  const NumberInputOsd({super.key, required this.buffer});

  @override
  Widget build(BuildContext context) {
    if (buffer.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: 32,
      right: 32,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 150),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.scale(
              scale: 0.9 + (0.1 * value),
              child: child,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.accent.withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: AppTheme.accent.withOpacity(0.1),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.dialpad_rounded,
                color: AppTheme.accent,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                buffer,
                style: const TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              // Blinking cursor
              _BlinkingCursor(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple blinking cursor for the OSD.
class _BlinkingCursor extends StatefulWidget {
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: 2,
          height: 28,
          margin: const EdgeInsets.only(left: 2),
          color: AppTheme.accent.withOpacity(_controller.value),
        );
      },
    );
  }
}
