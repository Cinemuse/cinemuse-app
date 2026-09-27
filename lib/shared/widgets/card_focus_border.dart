import 'package:flutter/material.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

/// A reusable focus and hover border overlay designed for cards and thumbnails.
///
/// Automatically retrieves focus and hover state from an enclosing [DpadFocusScope],
/// or uses explicitly provided [isFocused] / [isHovered] overrides.
///
/// Complies with 10-foot TV UI standards:
/// - **Focused (D-pad/Remote)**: High-contrast white border (2.0px) with focus glow.
/// - **Hovered (Desktop Mouse)**: Primary theme color border (1.5px).
/// - **Inactive**: Subtle card outline (1.0px).
class CardFocusBorder extends StatelessWidget {
  final BorderRadius borderRadius;
  final bool? isFocused;
  final bool? isHovered;
  final Duration duration;
  final Curve curve;

  const CardFocusBorder({
    super.key,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.isFocused,
    this.isHovered,
    this.duration = const Duration(milliseconds: 200),
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    final scope = DpadFocusScope.maybeOf(context);
    final effectiveFocused = isFocused ?? (scope?.isFocused ?? false);
    final effectiveHovered = isHovered ?? (scope?.isHovered ?? false);

    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    final Border border;

    if (effectiveFocused) {
      border = Border.all(
        color: primaryColor,
        width: 2.0,
      );
    } else if (effectiveHovered) {
      border = Border.all(
        color: primaryColor.withValues(alpha: 0.5),
        width: 1.5,
      );
    } else {
      border = Border.all(
        color: Colors.white.withValues(alpha: 0.1),
        width: 1.0,
      );
    }

    return IgnorePointer(
      child: AnimatedContainer(
        duration: duration,
        curve: curve,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: border,
        ),
      ),
    );
  }
}
