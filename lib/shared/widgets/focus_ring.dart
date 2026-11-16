import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/utils/platform_info.dart';
import 'package:cinemuse_app/shared/widgets/state_preview.dart';

/// The app's one keyboard / remote focus look (REV-252): a sharp white line
/// drawn [AppTheme.focusRingGap] outside [child], so it reads on bright
/// posters and accent buttons alike.
///
/// Painted outside the child's bounds without changing its layout, so
/// showing it never moves anything; the parent must not clip that margin.
///
/// Drawn only while [isKeyInput]: moving, scrolling or clicking the mouse,
/// or a touch, hides it, so the mouse never sees it even where a click or
/// a new page moves the focus.
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

  /// True after a key that moves or presses ([_navigationKeys]), false
  /// after the mouse moves, scrolls or clicks, or a touch. True at start
  /// only on a TV, so it shows the first focus at once; a PC shows no ring
  /// until the first arrow.
  static ValueListenable<bool> get isKeyInput {
    _watchInput;
    return _isKeyInput;
  }

  // PlatformInfo is ready before runApp, so before the first use here.
  static final _isKeyInput = ValueNotifier(PlatformInfo.isTV);

  /// A mouse moved less than this (logical pixels) since the last key was
  /// only bumped on the desk: the user is still on the keyboard.
  static const _mouseMoveSlop = 8.0;
  static double _mouseTravel = 0;

  // Static fields start on first use: the getter starts this one.
  static final bool _watchInput = () {
    HardwareKeyboard.instance.addHandler(_onKey);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    _isKeyInput.addListener(_followInFlutterWidgets);
    _followInFlutterWidgets();
    return true;
  }();

  /// Flutter's own widgets (an InkWell row, a text or icon button) draw their
  /// focus highlight by this setting: it goes with the ring too.
  static void _followInFlutterWidgets() {
    FocusManager.instance.highlightStrategy = _isKeyInput.value
        ? FocusHighlightStrategy.alwaysTraditional
        : FocusHighlightStrategy.alwaysTouch;
  }

  static void _onPointer(PointerEvent event) {
    switch (event) {
      case PointerDownEvent():
        _isKeyInput.value = false;
      case PointerHoverEvent(kind: PointerDeviceKind.mouse):
        _mouseTravel += event.delta.distance;
        if (_mouseTravel > _mouseMoveSlop) _isKeyInput.value = false;
      case PointerScrollEvent() || PointerPanZoomStartEvent():
        _isKeyInput.value = false;
    }
  }

  /// Only the keys that move the focus or press the focused item. Typing
  /// in Search, Esc, Space (pause) and the phone's volume / media buttons
  /// leave the mouse or touch look alone (user, 2026-10-20).
  static final _navigationKeys = {
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.tab,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.gameButtonA,
  };

  // Runs before the focus moves (Flutter's focus handler comes after the
  // keyboard handlers), so the first arrow already scrolls (REV-251).
  static bool _onKey(KeyEvent event) {
    if (!_navigationKeys.contains(event.logicalKey)) return false;
    _isKeyInput.value = true;
    _mouseTravel = 0;
    return false;
  }

  /// The test binding drops keyboard handlers after each test.
  @visibleForTesting
  static void debugWatchKeys() {
    _watchInput;
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  /// Back to the start (keys): the input of one test must not carry over to
  /// the next.
  @visibleForTesting
  static void debugResetInput() {
    _isKeyInput.value = true;
    _followInFlutterWidgets();
    _mouseTravel = 0;
  }

  @override
  Widget build(BuildContext context) {
    // Always the same widgets around [child]: swapping them on focus would
    // rebuild the child from scratch (an open DropdownButton menu closed).
    // A [StatePreview] shows the ring without a key press first.
    final isPreview = StatePreview.maybeOf(context)?.isFocused ?? false;
    return CustomPaint(
      foregroundPainter: _FocusRingPainter(
        isVisible,
        borderRadius,
        isInside,
        ignoresInput: isPreview,
      ),
      child: child,
    );
  }
}

/// A back arrow, for the mouse and touch: the keys and the remote have their
/// own Back and Esc. Hidden while [FocusRing.isKeyInput], keeping its place
/// so the page doesn't move under the mouse when it comes back. The control
/// from [builder] must use the focus node it gets.
class HiddenOnKeys extends StatefulWidget {
  final Widget Function(BuildContext context, FocusNode focusNode) builder;

  const HiddenOnKeys({super.key, required this.builder});

  @override
  State<HiddenOnKeys> createState() => _HiddenOnKeysState();
}

class _HiddenOnKeysState extends State<HiddenOnKeys> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    FocusRing.isKeyInput.addListener(_followInput);
    _followInput();
  }

  // Now, not at the next frame: the arrow key that hides the control is about
  // to move the focus, and must not land on it.
  void _followInput() {
    _focusNode.canRequestFocus = !FocusRing.isKeyInput.value;
  }

  @override
  void dispose() {
    FocusRing.isKeyInput.removeListener(_followInput);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPreview = StatePreview.maybeOf(context) != null;
    return ValueListenableBuilder(
      valueListenable: FocusRing.isKeyInput,
      builder: (context, isKeyInput, control) => Visibility(
        visible: !isKeyInput || isPreview,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: control!,
      ),
      child: widget.builder(context, _focusNode),
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

  void _onFocusChange(bool hasFocus) {
    // While the focus is inside, it can move between the row and a button
    // in it without leaving: follow every move.
    if (hasFocus) {
      FocusManager.instance.addListener(_update);
    } else {
      FocusManager.instance.removeListener(_update);
    }
    _update(hasFocus: hasFocus);
  }

  void _update({bool hasFocus = true}) {
    // A Flutter button inside draws its own ring ([ButtonFocusRing]): one
    // ring, never the row's around the button's.
    final onButton =
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorStateOfType<State<ButtonStyleButton>>() !=
        null;
    final isFocused = hasFocus && !onButton;
    if (mounted && isFocused != _isFocused) {
      setState(() => _isFocused = isFocused);
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_update);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only listens: the focus stays on the widgets inside.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: _onFocusChange,
      child: FocusRing(
        isVisible:
            _isFocused || (StatePreview.maybeOf(context)?.isFocused ?? false),
        borderRadius: widget.borderRadius,
        isInside: widget.isInside,
        // A preview is for this block only, not the controls inside it.
        child: StatePreview.maybeOf(context) == null
            ? widget.child
            : StatePreview(child: widget.child),
      ),
    );
  }
}

/// The [FocusRing] of every Flutter button (text, outlined, filled, icon):
/// the theme's buttons build it as their background layer, so a button
/// shows the ring with no wrapper of its own. Flutter clips that layer to
/// the button's shape, so the ring goes on the button's own edge.
class ButtonFocusRing extends StatelessWidget {
  final Set<WidgetState> states;
  final Widget? child;

  const ButtonFocusRing({super.key, required this.states, this.child});

  /// For `ButtonStyle.backgroundBuilder`.
  static Widget builder(
    BuildContext context,
    Set<WidgetState> states,
    Widget? child,
  ) => ButtonFocusRing(states: states, child: child);

  @override
  Widget build(BuildContext context) {
    // Below the button's Material: its shape gives the corners.
    final shape = context.findAncestorWidgetOfExactType<Material>()?.shape;
    final borderRadius = switch (shape) {
      RoundedRectangleBorder(:final borderRadius) => borderRadius.resolve(
        Directionality.maybeOf(context),
      ),
      StadiumBorder() || CircleBorder() => AppTheme.radiusFull,
      _ => AppTheme.radiusMd,
    };
    return FocusRing(
      isVisible:
          states.contains(WidgetState.focused) ||
          (StatePreview.maybeOf(context)?.isFocused ?? false),
      borderRadius: borderRadius,
      isInside: true,
      child: child ?? const SizedBox.shrink(),
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  final bool isVisible;
  final BorderRadius borderRadius;
  final bool isInside;

  final bool ignoresInput;

  _FocusRingPainter(
    this.isVisible,
    this.borderRadius,
    this.isInside, {
    this.ignoresInput = false,
  }) : super(repaint: FocusRing.isKeyInput);

  @override
  void paint(Canvas canvas, Size size) {
    if (!isVisible) return;
    if (!ignoresInput && !FocusRing.isKeyInput.value) return;
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
      oldDelegate.isInside != isInside ||
      oldDelegate.ignoresInput != ignoresInput;
}
