import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
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
  final String? tooltip;

  const SearchHoverButton({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.onKeyEvent,
    this.focusNode,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
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
                ? AppTheme.accentHoverBg
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
