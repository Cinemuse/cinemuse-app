import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';

/// The app's one keyboard / remote focus look (REV-252): a sharp white line
/// drawn [AppTheme.focusRingGap] outside [child], so it reads on bright
/// posters and accent buttons alike.
///
/// Painted outside the child's bounds without changing its layout, so
/// showing it never moves anything; the parent must not clip that margin.
class FocusRing extends StatelessWidget {
  final bool isVisible;

  /// The child's own corner radius; the ring follows it at the gap.
  final BorderRadius borderRadius;

  /// Draws the line on the child's own edge instead of outside it, for
  /// items packed edge to edge in a clipped row (the TV guide), where the
  /// outer ring would be cut off or painted over by the next item.
  final bool isInside;
  final Widget child;

  const FocusRing({
    super.key,
    required this.isVisible,
    this.borderRadius = AppTheme.radiusMd,
    this.isInside = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return child;
    return CustomPaint(
      foregroundPainter: _FocusRingPainter(borderRadius, isInside),
      child: child,
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  final BorderRadius borderRadius;
  final bool isInside;

  const _FocusRingPainter(this.borderRadius, this.isInside);

  @override
  void paint(Canvas canvas, Size size) {
    final outset = isInside
        ? -AppTheme.focusRingWidth / 2
        : AppTheme.focusRingGap + AppTheme.focusRingWidth / 2;
    final ring = borderRadius.toRRect(Offset.zero & size).inflate(outset);
    canvas.drawRRect(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppTheme.focusRingWidth
        ..color = AppTheme.focusRing,
    );
  }

  @override
  bool shouldRepaint(_FocusRingPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.isInside != isInside;
}
