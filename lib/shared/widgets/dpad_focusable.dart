import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';

typedef DpadFocusableBuilder =
    Widget Function(
      BuildContext context,
      bool isFocused,
      bool isHovered,
      Widget child,
    );

/// A reusable interactive wrapper that equips its child with:
/// - D-Pad & keyboard navigation (Up/Down/Left/Right directional focus)
/// - Activation (Enter, Space, D-Pad Center/Select, Gamepad A)
/// - Context actions (ContextMenu key, Shift+F10, Gamepad X/Y, Enter held,
///   Long Press, Secondary click)
/// - Mouse hover detection & cursor handling (Desktop)
/// - Touch handling (Mobile)
/// - Auto-scrolling the parent [Scrollable] into view when focused
/// - Optional animated scaling on hover and focus
/// - The app's [FocusRing] on keyboard / remote focus only (REV-252)
class DpadFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;

  /// Right-click with its position, e.g. to open a menu there (REV-248).
  final GestureTapDownCallback? onSecondaryTapDown;
  final ValueChanged<bool>? onFocusChange;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool autoScroll;
  final double scale;
  final Duration duration;
  final Curve curve;

  /// Off only where the child draws the [FocusRing] itself around a part
  /// of it (e.g. a card's picture, not its title).
  final bool showFocusRing;

  /// The child's corner radius, followed by the focus ring.
  final BorderRadius? borderRadius;

  /// See [FocusRing.isInside].
  final bool isFocusRingInside;
  final DpadFocusableBuilder? builder;
  final FocusOnKeyEventCallback? onKeyEvent;

  /// Shown on mouse hover; required for icon-only buttons (REV-253).
  final String? tooltip;

  const DpadFocusable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.onSecondaryTapDown,
    this.onFocusChange,
    this.focusNode,
    this.autofocus = false,
    this.autoScroll = true,
    this.scale = 1.0,
    this.duration = const Duration(milliseconds: 200),
    this.curve = Curves.easeOutCubic,
    this.showFocusRing = true,
    this.borderRadius,
    this.isFocusRingInside = false,
    this.builder,
    this.onKeyEvent,
    this.tooltip,
  });

  @override
  State<DpadFocusable> createState() => _DpadFocusableState();
}

class _DpadFocusableState extends State<DpadFocusable> {
  FocusNode? _internalFocusNode;
  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  bool _isFocused = false;
  bool _isHovered = false;

  // A keyboard or TV remote sends key repeats, not a long press: with an
  // [onLongPress], an activation key held this long opens it (REV-284).
  static const _keyLongPressDelay = Duration(milliseconds: 500);
  Timer? _keyLongPressTimer;
  LogicalKeyboardKey? _heldActivationKey;

  @override
  void initState() {
    super.initState();
    _effectiveFocusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(DpadFocusable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode?.removeListener(_handleFocusChanged);
      _internalFocusNode?.removeListener(_handleFocusChanged);
      _effectiveFocusNode.addListener(_handleFocusChanged);
    }
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_handleFocusChanged);
    _keyLongPressTimer?.cancel();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    final hasFocus = _effectiveFocusNode.hasFocus;
    if (_isFocused == hasFocus) return;
    if (!hasFocus) _cancelHeldActivationKey();

    setState(() => _isFocused = hasFocus);
    widget.onFocusChange?.call(hasFocus);

    if (hasFocus && widget.autoScroll) {
      _autoScrollIntoView();
    }
  }

  void _handleHoverChanged(bool isHovered) {
    if (_isHovered == isHovered) return;
    setState(() => _isHovered = isHovered);
  }

  void _autoScrollIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_effectiveFocusNode.hasFocus) return;

      final renderObject = context.findRenderObject();
      if (renderObject == null || !renderObject.attached) return;

      // 1. Immediate scrollable (e.g. horizontal carousel row or single list)
      final scrollable = Scrollable.maybeOf(context);
      if (scrollable == null) return;
      if (scrollable.position.hasPixels) {
        _reveal(scrollable.position, renderObject, 24.0);
      }

      // 2. Outer vertical scrollable (e.g. Page scrollable for HomeScreen Column)
      final parent = scrollable.context
          .findAncestorStateOfType<ScrollableState>();
      if (parent != null &&
          parent.position.hasPixels &&
          parent.position.axis == Axis.vertical) {
        final rowRenderObject = scrollable.context.findRenderObject();
        if (rowRenderObject != null && rowRenderObject.attached) {
          _reveal(parent.position, rowRenderObject, 32.0);
        }
      }
    });
  }

  /// Scrolls [position] just enough to show [target] with [margin] around it,
  /// only when it is off-screen or clipped (so focus moves don't jitter).
  static void _reveal(
    ScrollPosition position,
    RenderObject target,
    double margin,
  ) {
    final viewport = RenderAbstractViewport.maybeOf(target);
    if (viewport == null) return;

    final current = position.pixels;
    final revealLeading = viewport.getOffsetToReveal(target, 0.0).offset;
    final revealTrailing = viewport.getOffsetToReveal(target, 1.0).offset;
    final minComfortable = revealTrailing + margin;
    final maxComfortable = revealLeading - margin;

    final isComfortablyVisible = minComfortable <= maxComfortable
        ? (current >= minComfortable && current <= maxComfortable)
        : (current >= revealTrailing && current <= revealLeading);
    if (isComfortablyVisible) return;

    final targetOffset = current < minComfortable
        ? revealTrailing + (margin * 2)
        : revealLeading - (margin * 2);
    final clamped = targetOffset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    if ((clamped - current).abs() > 2.0) {
      position.animateTo(
        clamped,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _handleAction() {
    widget.onTap?.call();
  }

  void _handleContextAction() {
    widget.onLongPress?.call();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (widget.onKeyEvent != null) {
      final customResult = widget.onKeyEvent!(node, event);
      if (customResult != KeyEventResult.ignored) {
        return customResult;
      }
    }

    // Primary Activation Keys: Enter, NumpadEnter, Select, Space, GameButtonA
    final isActivationKey =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA;

    if (isActivationKey && widget.onLongPress != null) {
      return _handleHoldableActivationKey(event);
    }

    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (isActivationKey) {
      if (widget.onTap != null) {
        _handleAction();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Secondary / Context Menu Keys: ContextMenu, Shift+F10, GameButtonX, GameButtonY
    final isContextKey =
        event.logicalKey == LogicalKeyboardKey.contextMenu ||
        (event.logicalKey == LogicalKeyboardKey.f10 &&
            HardwareKeyboard.instance.isShiftPressed) ||
        event.logicalKey == LogicalKeyboardKey.gameButtonX ||
        event.logicalKey == LogicalKeyboardKey.gameButtonY;

    if (isContextKey && widget.onLongPress != null) {
      _handleContextAction();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// Tap on release, long press once the key is held for
  /// [_keyLongPressDelay]; the release after a long press does nothing.
  KeyEventResult _handleHoldableActivationKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      _cancelHeldActivationKey();
      _heldActivationKey = event.logicalKey;
      _keyLongPressTimer = Timer(_keyLongPressDelay, _handleContextAction);
      return KeyEventResult.handled;
    }
    // A key pressed before this control had focus is not ours.
    if (event.logicalKey != _heldActivationKey) return KeyEventResult.ignored;
    if (event is KeyUpEvent) {
      final isShortPress = _keyLongPressTimer?.isActive ?? false;
      _cancelHeldActivationKey();
      if (isShortPress) _handleAction();
    }
    return KeyEventResult.handled;
  }

  void _cancelHeldActivationKey() {
    _keyLongPressTimer?.cancel();
    _keyLongPressTimer = null;
    _heldActivationKey = null;
  }

  Widget _buildContent(BuildContext context) {
    Widget content = widget.child;

    if (widget.builder != null) {
      content = widget.builder!(context, _isFocused, _isHovered, content);
    }
    // Hover only scales; the ring marks what Enter opens (REV-252).
    content = FocusRing(
      isVisible: widget.showFocusRing && _isFocused,
      borderRadius: widget.borderRadius ?? AppTheme.radiusMd,
      isInside: widget.isFocusRingInside,
      child: content,
    );

    if (widget.scale != 1.0) {
      final isHighlighted = _isFocused || _isHovered;
      content = AnimatedScale(
        scale: isHighlighted ? widget.scale : 1.0,
        duration: widget.duration,
        curve: widget.curve,
        child: content,
      );
    }

    return content;
  }

  @override
  Widget build(BuildContext context) {
    final focusable = Focus(
      focusNode: _effectiveFocusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _handleKeyEvent,
      child: MouseRegion(
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => _handleHoverChanged(true),
        onExit: (_) => _handleHoverChanged(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Only claim the tap when there is an action: an always-set onTap
          // wins against an outer GestureDetector and swallows its tap (REV-39).
          onTap: widget.onTap == null
              ? null
              : () {
                  _effectiveFocusNode.requestFocus();
                  _handleAction();
                },
          onLongPress: widget.onLongPress,
          onSecondaryTap: widget.onSecondaryTap,
          onSecondaryTapDown: widget.onSecondaryTapDown,
          child: DpadFocusScope(
            isFocused: _isFocused,
            isHovered: _isHovered,
            child: _buildContent(context),
          ),
        ),
      ),
    );
    final tooltip = widget.tooltip;
    if (tooltip == null) return focusable;
    return Tooltip(message: tooltip, child: focusable);
  }
}

/// An [InheritedWidget] exposing the focus and hover state of an ancestor [DpadFocusable].
class DpadFocusScope extends InheritedWidget {
  final bool isFocused;
  final bool isHovered;

  const DpadFocusScope({
    super.key,
    required this.isFocused,
    required this.isHovered,
    required super.child,
  });

  bool get isHighlighted => isFocused || isHovered;

  static DpadFocusScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DpadFocusScope>();
  }

  @override
  bool updateShouldNotify(DpadFocusScope oldWidget) {
    return isFocused != oldWidget.isFocused || isHovered != oldWidget.isHovered;
  }
}
