import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';

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
/// - Context actions (ContextMenu key, Gamepad X/Y, Long Press, Secondary click)
/// - Mouse hover detection & cursor handling (Desktop)
/// - Touch handling (Mobile)
/// - Auto-scrolling the parent [Scrollable] into view when focused
/// - Optional animated scaling and focused glow/border indicators
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
  final bool showFocusRing;
  final BorderRadius? borderRadius;
  final Color? focusRingColor;
  final double focusRingWidth;
  final DpadFocusableBuilder? builder;
  final FocusOnKeyEventCallback? onKeyEvent;

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
    this.showFocusRing = false,
    this.borderRadius,
    this.focusRingColor,
    this.focusRingWidth = 2.0,
    this.builder,
    this.onKeyEvent,
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
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    final hasFocus = _effectiveFocusNode.hasFocus;
    if (_isFocused == hasFocus) return;

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

    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Primary Activation Keys: Enter, NumpadEnter, Select, Space, GameButtonA
    final isActivationKey =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA;

    if (isActivationKey) {
      if (widget.onTap != null) {
        _handleAction();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Secondary / Context Menu Keys: ContextMenu, GameButtonX, GameButtonY
    final isContextKey =
        event.logicalKey == LogicalKeyboardKey.contextMenu ||
        event.logicalKey == LogicalKeyboardKey.gameButtonX ||
        event.logicalKey == LogicalKeyboardKey.gameButtonY;

    if (isContextKey && widget.onLongPress != null) {
      _handleContextAction();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Widget _buildFocusRing(Widget child) {
    if (!widget.showFocusRing || !_isFocused) {
      return child;
    }

    final radius = widget.borderRadius ?? BorderRadius.circular(8);
    final ringColor = widget.focusRingColor ?? AppTheme.focusRing;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: ringColor, width: widget.focusRingWidth),
        boxShadow: AppTheme.shadowFocusGlow,
      ),
      position: DecorationPosition.foreground,
      child: child,
    );
  }

  Widget _buildContent(BuildContext context) {
    Widget content = widget.child;

    if (widget.builder != null) {
      content = widget.builder!(context, _isFocused, _isHovered, content);
    } else {
      content = _buildFocusRing(content);
    }

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
    return Focus(
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
