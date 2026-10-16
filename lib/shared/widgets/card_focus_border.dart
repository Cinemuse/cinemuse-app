import 'package:flutter/material.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';

/// The outline of a card's picture.
///
/// - **Always**: a subtle white line (1.0px).
/// - **Focused (keyboard / remote)**: plus the app's [FocusRing] around the
///   picture, so the card's owner [DpadFocusable] sets
///   `showFocusRing: false` (REV-252).
///
/// Hover draws no frame: the card only grows and its title turns pink.
/// Reads the focus from an enclosing [DpadFocusScope] unless [isFocused]
/// is given.
class CardFocusBorder extends StatelessWidget {
  final BorderRadius borderRadius;
  final bool? isFocused;

  const CardFocusBorder({
    super.key,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.isFocused,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveFocused =
        isFocused ?? (DpadFocusScope.maybeOf(context)?.isFocused ?? false);

    return IgnorePointer(
      child: FocusRing(
        isVisible: effectiveFocused,
        borderRadius: borderRadius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
      ),
    );
  }
}
