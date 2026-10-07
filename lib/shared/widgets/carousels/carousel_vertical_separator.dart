import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Reusable vertical separator for horizontal carousels.
/// Displays a stylized pill badge flanked by top and bottom gradient lines.
class CarouselVerticalSeparator extends StatelessWidget {
  final String label;
  final bool isHighlighted;
  final double width;
  final double lineHeight;
  final double trailingSpacing;
  final double leadingSpacing;
  final Color? color;

  const CarouselVerticalSeparator({
    super.key,
    required this.label,
    this.isHighlighted = false,
    this.width = 72,
    this.lineHeight = 48,
    this.trailingSpacing = 16,
    this.leadingSpacing = 0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = color ?? theme.colorScheme.primary;
    final borderColor = isHighlighted ? activeColor : AppTheme.border;

    return Padding(
      padding: EdgeInsets.only(left: leadingSpacing, right: trailingSpacing),
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 2,
              height: lineHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    borderColor,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isHighlighted
                    ? activeColor.withValues(alpha: 0.15)
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isHighlighted
                      ? activeColor.withValues(alpha: 0.5)
                      : AppTheme.border,
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: isHighlighted ? activeColor : AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: 1.1,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 2,
              height: lineHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    borderColor,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
