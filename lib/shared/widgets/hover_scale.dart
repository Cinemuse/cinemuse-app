import 'package:flutter/material.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

/// Interactive wrapper that scales on mouse hover, touch, and D-Pad / remote focus.
/// Backwards-compatible drop-in replacement for existing HoverScale usages.
class HoverScale extends StatelessWidget {
  final Widget child;
  final double scale;
  final Duration duration;
  final Curve curve;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final ValueChanged<bool>? onFocusChange;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool autoScroll;
  final bool showFocusRing;
  final BorderRadius? borderRadius;
  final Color? focusRingColor;
  final DpadFocusableBuilder? builder;
  final String? tooltip;

  const HoverScale({
    super.key,
    required this.child,
    this.scale = 1.05,
    this.duration = const Duration(milliseconds: 200),
    this.curve = Curves.easeOutCubic,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.onFocusChange,
    this.focusNode,
    this.autofocus = false,
    this.autoScroll = true,
    this.showFocusRing = false,
    this.borderRadius,
    this.focusRingColor,
    this.builder,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return DpadFocusable(
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTap: onSecondaryTap,
      onFocusChange: onFocusChange,
      focusNode: focusNode,
      autofocus: autofocus,
      autoScroll: autoScroll,
      scale: scale,
      duration: duration,
      curve: curve,
      showFocusRing: showFocusRing,
      borderRadius: borderRadius,
      focusRingColor: focusRingColor,
      builder: builder,
      tooltip: tooltip,
      child: child,
    );
  }
}
