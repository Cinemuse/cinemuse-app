import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';

/// The app's one keyboard / remote focus look (REV-252): a sharp white line
/// drawn [AppTheme.focusRingGap] outside [child], so it reads on bright
/// posters and accent buttons alike.
///
/// Painted outside the child's bounds without changing its layout, so
/// showing it never moves anything; the parent must not clip that margin.
///
/// Drawn only while [isKeyInput]: a click or touch hides it, so the mouse
/// never sees it even where a click moves the focus.
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

  /// True after a key press (keyboard / remote), false after a click or
  /// touch. True at start, so a TV shows the first focus at once.
  static ValueListenable<bool> get isKeyInput => _isKeyInput;

  static final ValueNotifier<bool> _isKeyInput = () {
    HardwareKeyboard.instance.addHandler(_onKey);
    GestureBinding.instance.pointerRouter.addGlobalRoute((event) {
      if (event is PointerDownEvent) _isKeyInput.value = false;
    });
    return ValueNotifier(true);
  }();

  static bool _onKey(KeyEvent _) {
    _isKeyInput.value = true;
    return false;
  }

  /// The test binding drops keyboard handlers after each test.
  @visibleForTesting
  static void debugWatchKeys() {
    isKeyInput;
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  Widget build(BuildContext context) {
    // Always the same widgets around [child]: swapping them on focus would
    // rebuild the child from scratch (an open DropdownButton menu closed).
    return CustomPaint(
      foregroundPainter: _FocusRingPainter(isVisible, borderRadius, isInside),
      child: child,
    );
  }
}

/// The [FocusRing] for a Flutter widget that has no `DpadFocusable` of its
/// own (an InkWell row, a DropdownButton): wrap it once and the ring shows
/// while the keyboard / remote focus is anywhere inside [child].
class FocusRingFollower extends StatefulWidget {
  final BorderRadius borderRadius;
  final bool isInside;
  final Widget child;

  const FocusRingFollower({
    super.key,
    this.borderRadius = AppTheme.radiusMd,
    this.isInside = false,
    required this.child,
  });

  @override
  State<FocusRingFollower> createState() => _FocusRingFollowerState();
}

class _FocusRingFollowerState extends State<FocusRingFollower> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    // Only listens: the focus stays on the widgets inside.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
      child: FocusRing(
        isVisible: _isFocused,
        borderRadius: widget.borderRadius,
        isInside: widget.isInside,
        child: widget.child,
      ),
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  final bool isVisible;
  final BorderRadius borderRadius;
  final bool isInside;

  _FocusRingPainter(this.isVisible, this.borderRadius, this.isInside)
    : super(repaint: FocusRing.isKeyInput);

  @override
  void paint(Canvas canvas, Size size) {
    if (!isVisible || !FocusRing.isKeyInput.value) return;
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
      oldDelegate.isVisible != isVisible ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.isInside != isInside;
}
