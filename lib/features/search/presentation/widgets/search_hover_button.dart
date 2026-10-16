import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:flutter/material.dart';

/// A search overlay button whose background lights up on hover and focus
/// (the focus ring comes from [DpadFocusable]).
class SearchHoverButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final FocusOnKeyEventCallback? onKeyEvent;
  final FocusNode? focusNode;
  final BorderRadius borderRadius;

  /// White opacity of the background when hovered or focused.
  final double highlightAlpha;
  final String? tooltip;

  const SearchHoverButton({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.onKeyEvent,
    this.focusNode,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.highlightAlpha = 0.12,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return DpadFocusable(
      focusNode: focusNode,
      borderRadius: borderRadius,
      onTap: onTap,
      onLongPress: onLongPress,
      onKeyEvent: onKeyEvent,
      tooltip: tooltip,
      builder: (context, isFocused, isHovered, child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: (isFocused || isHovered)
                ? Colors.white.withValues(alpha: highlightAlpha)
                : Colors.transparent,
            borderRadius: borderRadius,
          ),
          child: child,
        );
      },
      child: child,
    );
  }
}
