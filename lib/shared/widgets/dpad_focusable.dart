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
  final ValueChanged<bool>? onFocusChange;
  final ValueChanged<bool>? onHoverChange;
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
  final List<BoxShadow>? focusGlow;
  final DpadFocusableBuilder? builder;
  final FocusOnKeyEventCallback? onKeyEvent;

  const DpadFocusable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.onFocusChange,
    this.onHoverChange,
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
    this.focusGlow,
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
    widget.onHoverChange?.call(isHovered);
  }

  void _autoScrollIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_effectiveFocusNode.hasFocus) return;

      final renderObject = context.findRenderObject();
      if (renderObject == null || !renderObject.attached) return;

      // 1. Immediate scrollable (e.g. horizontal carousel row or single list)
      final scrollable = Scrollable.maybeOf(context);
      if (scrollable != null && scrollable.position.hasPixels) {
        final position = scrollable.position;
        final viewport = RenderAbstractViewport.maybeOf(renderObject);
        if (viewport != null) {
          final current = position.pixels;
          final revealLeading = viewport.getOffsetToReveal(renderObject, 0.0);
          final revealTrailing = viewport.getOffsetToReveal(renderObject, 1.0);

          // Margin to consider an item "comfortably visible" without jitter
          const margin = 24.0;
          final minComfortable = revealTrailing.offset + margin;
          final maxComfortable = revealLeading.offset - margin;

          final bool isComfortablyVisible = minComfortable <= maxComfortable
              ? (current >= minComfortable && current <= maxComfortable)
              : (current >= revealTrailing.offset &&
                    current <= revealLeading.offset);

          if (!isComfortablyVisible) {
            // Only scroll the carousel when the item is actually off-screen or clipped
            double targetOffset;
            if (current < minComfortable) {
              // Off the trailing edge: scroll just enough to show it with margin
              targetOffset = revealTrailing.offset + (margin * 2);
            } else {
              // Off the leading edge: scroll just enough to show it with margin
              targetOffset = revealLeading.offset - (margin * 2);
            }

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
        }
      }

      // 2. Outer vertical scrollable (e.g. Page scrollable for HomeScreen Column)
      final parentScrollableState = scrollable?.context
          .findAncestorStateOfType<ScrollableState>();
      if (parentScrollableState != null &&
          parentScrollableState.position.hasPixels &&
          parentScrollableState.position.axis == Axis.vertical) {
        final vPosition = parentScrollableState.position;
        final rowRenderObject = scrollable!.context.findRenderObject();
        if (rowRenderObject != null && rowRenderObject.attached) {
          final vViewport = RenderAbstractViewport.maybeOf(rowRenderObject);
          if (vViewport != null) {
            final current = vPosition.pixels;
            final revealLeading = vViewport.getOffsetToReveal(
              rowRenderObject,
              0.0,
            );
            final revealTrailing = vViewport.getOffsetToReveal(
              rowRenderObject,
              1.0,
            );

            const vMargin = 32.0;
            final minComfortable = revealTrailing.offset + vMargin;
            final maxComfortable = revealLeading.offset - vMargin;

            final bool isRowVisible = minComfortable <= maxComfortable
                ? (current >= minComfortable && current <= maxComfortable)
                : (current >= revealTrailing.offset &&
                      current <= revealLeading.offset);

            if (!isRowVisible) {
              double targetOffset;
              if (current < minComfortable) {
                targetOffset = revealTrailing.offset + (vMargin * 2);
              } else {
                targetOffset = revealLeading.offset - (vMargin * 2);
              }

              final clamped = targetOffset.clamp(
                vPosition.minScrollExtent,
                vPosition.maxScrollExtent,
              );

              if ((clamped - current).abs() > 2.0) {
                vPosition.animateTo(
                  clamped,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                );
              }
            }
          }
        }
      }
    });
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
    final glow = widget.focusGlow ?? AppTheme.shadowFocusGlow;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: ringColor, width: widget.focusRingWidth),
        boxShadow: glow,
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

  static DpadFocusScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'No DpadFocusScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(DpadFocusScope oldWidget) {
    return isFocused != oldWidget.isFocused || isHovered != oldWidget.isHovered;
  }
}
