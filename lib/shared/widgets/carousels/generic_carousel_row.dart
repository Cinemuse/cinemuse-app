import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/carousels/carousel_arrow_buttons.dart';
import 'package:cinemuse_app/shared/widgets/carousels/carousel_arrow_step.dart';
import 'package:cinemuse_app/shared/widgets/carousels/carousel_row_frame.dart';

export 'package:cinemuse_app/shared/widgets/carousels/carousel_row_frame.dart'
    show CarouselTheme;

class GenericCarouselRow extends StatefulWidget {
  final String? title;
  final IconData? icon;
  final CarouselTheme theme;
  final Widget? headerAction;
  final ScrollController? controller;
  final VoidCallback? onHeaderTap;
  final WidgetBuilder? emptyBuilder;
  final double height;
  final int itemCount;
  final EdgeInsets padding;
  final IndexedWidgetBuilder itemBuilder;
  final IndexedWidgetBuilder? separatorBuilder;

  const GenericCarouselRow({
    super.key,
    this.title,
    this.icon,
    this.theme = CarouselTheme.homeRow,
    this.headerAction,
    this.controller,
    this.onHeaderTap,
    this.emptyBuilder,
    required this.height,
    required this.itemCount,
    this.padding = EdgeInsets.zero,
    required this.itemBuilder,
    this.separatorBuilder,
  });

  @override
  State<GenericCarouselRow> createState() => _GenericCarouselRowState();
}

class _GenericCarouselRowState extends State<GenericCarouselRow> {
  late ScrollController _controller;
  late final FocusNode _rowFocusNode;
  final Map<int, FocusNode> _trackedNodes = {};
  FocusNode? _lastFocusedNode;
  bool _wasFocused = false;
  // A notifier, not state: hovering must not rebuild the row's cards (REV-41).
  final ValueNotifier<bool> _isHovering = ValueNotifier(false);

  // The list's left padding, where an arrow step lines an item up.
  double _listLeadingPadding = 0;

  @override
  void initState() {
    super.initState();
    _rowFocusNode = FocusNode(
      debugLabel: 'Carousel_${widget.title ?? "Row"}',
      canRequestFocus: false,
      skipTraversal: true,
    );
    _rowFocusNode.addListener(_handleRowFocusChange);
    _controller = widget.controller ?? ScrollController();
  }

  @override
  void didUpdateWidget(GenericCarouselRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (oldWidget.controller == null) _controller.dispose();
      _controller = widget.controller ?? ScrollController();
    }
    if (widget.itemCount < oldWidget.itemCount) {
      final removed = _trackedNodes.keys
          .where((index) => index >= widget.itemCount)
          .toList();
      final staleNodes = [for (final i in removed) _trackedNodes.remove(i)!];
      // The old items still hold these nodes until this frame rebuilds them away.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final node in staleNodes) {
          node.dispose();
        }
      });
    }
  }

  @override
  void dispose() {
    for (final node in _trackedNodes.values) {
      node.dispose();
    }
    _trackedNodes.clear();
    _rowFocusNode.removeListener(_handleRowFocusChange);
    _rowFocusNode.dispose();
    _isHovering.dispose();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleRowFocusChange() {
    final hasFocus = _rowFocusNode.hasFocus;
    if (!_wasFocused && hasFocus) {
      if (_lastFocusedNode != null &&
          _lastFocusedNode!.canRequestFocus &&
          !_lastFocusedNode!.hasFocus) {
        // Row Memory: restore last focused item
        final target = _lastFocusedNode!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _rowFocusNode.hasFocus && target.canRequestFocus) {
            target.requestFocus();
          }
        });
      } else if (_lastFocusedNode == null) {
        // First time reaching this row: start from the first card on the left!
        // Scroll back first: only the cards near the view are built (REV-41).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_rowFocusNode.hasFocus) return;
          if (_controller.hasClients && _controller.position.pixels > 0) {
            _controller.jumpTo(0.0);
            WidgetsBinding.instance.addPostFrameCallback((_) => _focusFirst());
          } else {
            _focusFirst();
          }
        });
      }
      _wasFocused = true;
    } else if (!hasFocus) {
      _wasFocused = false;
    }
  }

  void _focusFirst() {
    if (!mounted) return;
    final firstFocusable = _getFirstFocusableNode();
    if (firstFocusable == null) return;
    firstFocusable.requestFocus();
    _lastFocusedNode = firstFocusable;
  }

  void _scrollPage({required bool isForward}) {
    if (!_controller.hasClients) return;
    final target = carouselArrowTarget(
      position: _controller.position,
      // Cards scrolled far away are no longer built: their context is gone.
      items: [
        for (final n in _trackedNodes.values)
          if (n.context?.mounted ?? false) n.context!.findRenderObject(),
      ],
      leadingPadding: _listLeadingPadding,
      isForward: isForward,
    );
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  FocusNode _getOrCreateTrackedNode(int index) {
    return _trackedNodes.putIfAbsent(
      index,
      () => FocusNode(
        debugLabel: 'Carousel_${widget.title ?? "Item"}_$index',
        canRequestFocus: false,
        skipTraversal: true,
      ),
    );
  }

  bool _isFirstFocusableIndex(int index) {
    if (index == 0) return true;
    final firstNode = _getFirstFocusableNode();
    final currentNode = _trackedNodes[index];
    if (firstNode != null && currentNode != null) {
      return firstNode == currentNode ||
          currentNode.descendants.contains(firstNode);
    }
    return false;
  }

  bool _isLastFocusableIndex(int index, int totalCount) {
    if (index >= totalCount - 1) return true;
    final lastNode = _getLastFocusableNode();
    final currentNode = _trackedNodes[index];
    if (lastNode != null && currentNode != null) {
      return lastNode == currentNode ||
          currentNode.descendants.contains(lastNode);
    }
    return false;
  }

  FocusNode? _getFirstFocusableNode() {
    final sortedIndices = _trackedNodes.keys.toList()..sort();
    for (final i in sortedIndices) {
      final node = _trackedNodes[i];
      if (node == null) continue;
      if (node.canRequestFocus) return node;
      for (final d in node.descendants) {
        if (d.canRequestFocus) return d;
      }
    }
    for (final d in _rowFocusNode.descendants) {
      if (d.canRequestFocus && d != _rowFocusNode) return d;
    }
    return null;
  }

  FocusNode? _getLastFocusableNode() {
    final sortedIndices = _trackedNodes.keys.toList()..sort();
    for (final i in sortedIndices.reversed) {
      final node = _trackedNodes[i];
      if (node == null) continue;
      if (node.canRequestFocus) return node;
      for (final d in node.descendants) {
        if (d.canRequestFocus) return d;
      }
    }
    return null;
  }

  Widget _buildTrackedItem(BuildContext context, int index, int totalCount) {
    final item = widget.itemBuilder(context, index);
    final node = _getOrCreateTrackedNode(index);

    return _KeepAliveWhileFocused(
      node: node,
      child: Focus(
        focusNode: node,
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (hasFocus) {
          if (hasFocus) {
            if (_wasFocused) {
              _lastFocusedNode = FocusManager.instance.primaryFocus;
            }
            if (_isFirstFocusableIndex(index)) {
              // Reveal leading headers (e.g. "Today" marker in sport schedule)
              if (_controller.hasClients && _controller.position.pixels > 0) {
                _controller.animateTo(
                  0.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                );
              }
            }
          }
        },
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
            return KeyEventResult.ignored;
          }

          if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
              _isFirstFocusableIndex(index)) {
            // Always consume arrowLeft at leftmost focusable item so it NEVER escapes or jumps between rows
            return KeyEventResult.handled;
          }

          if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
              _isLastFocusableIndex(index, totalCount)) {
            return KeyEventResult.handled;
          }

          return KeyEventResult.ignored;
        },
        child: item,
      ),
    );
  }

  Widget _buildList(EdgeInsets padding) {
    if (widget.itemCount == 0 && widget.emptyBuilder != null) {
      return widget.emptyBuilder!(context);
    }
    if (widget.itemCount == 0) return const SizedBox.shrink();

    _listLeadingPadding = padding.left;
    final effectivePadding = padding.copyWith(bottom: padding.bottom + 16);

    final count = widget.itemCount;

    // One screen width built on each side, not every card (REV-41): enough
    // for the D-pad to reach the next card and for an arrow step to measure a
    // page back (carouselArrowTarget sees only built items).
    final list = LayoutBuilder(
      builder: (context, constraints) => ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: effectivePadding,
        cacheExtent: constraints.maxWidth,
        itemCount: count,
        separatorBuilder:
            widget.separatorBuilder ?? (_, _) => const SizedBox.shrink(),
        itemBuilder: (context, index) =>
            _buildTrackedItem(context, index, count),
      ),
    );

    return SizedBox(
      height: widget.height,
      child: RawScrollbar(
        controller: _controller,
        thumbColor: AppTheme.accent.withValues(alpha: 0.5),
        radius: const Radius.circular(8),
        thickness: 6,
        minThumbLength: 50,
        interactive: true,
        padding: EdgeInsets.only(
          bottom: 2,
          left: padding.left,
          right: padding.right,
        ),
        child: Focus(focusNode: _rowFocusNode, child: list),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0 && widget.emptyBuilder == null) {
      return const SizedBox.shrink();
    }
    final content = CarouselRowFrame(
      theme: widget.theme,
      title: widget.title,
      icon: widget.icon,
      headerAction: widget.headerAction,
      onHeaderTap: widget.onHeaderTap,
      padding: widget.padding,
      arrows: CarouselArrowButtons(
        controller: _controller,
        isHovering: _isHovering,
        onStep: _scrollPage,
      ),
      buildList: _buildList,
    );

    return MouseRegion(
      onEnter: (_) => _isHovering.value = true,
      onExit: (_) => _isHovering.value = false,
      child: content,
    );
  }
}

/// Keeps a focused card built when it scrolls far out of view (REV-41):
/// thrown away, its focus would jump back to the row above.
class _KeepAliveWhileFocused extends StatefulWidget {
  final FocusNode node;
  final Widget child;

  const _KeepAliveWhileFocused({required this.node, required this.child});

  @override
  State<_KeepAliveWhileFocused> createState() => _KeepAliveWhileFocusedState();
}

class _KeepAliveWhileFocusedState extends State<_KeepAliveWhileFocused>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.node.hasFocus;

  @override
  void initState() {
    super.initState();
    widget.node.addListener(updateKeepAlive);
  }

  @override
  void didUpdateWidget(_KeepAliveWhileFocused oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.node != oldWidget.node) {
      oldWidget.node.removeListener(updateKeepAlive);
      widget.node.addListener(updateKeepAlive);
      updateKeepAlive();
    }
  }

  @override
  void dispose() {
    widget.node.removeListener(updateKeepAlive);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
