import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/bento_box.dart';

enum CarouselTheme {
  homeRow, // Title + chevron right (no box)
  profileRow, // Icon + Title + chevron right inside a container with surface color
  bentoBox, // BentoBox with title and icon
  plain, // No header
}

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
  bool _canScrollLeft = false;
  bool _canScrollRight = false;
  bool _isHoveringList = false;

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
    _controller.addListener(_updateScrollButtons);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollButtons();
    });
  }

  @override
  void didUpdateWidget(GenericCarouselRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _controller.removeListener(_updateScrollButtons);
      if (oldWidget.controller == null) _controller.dispose();
      _controller = widget.controller ?? ScrollController();
      _controller.addListener(_updateScrollButtons);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateScrollButtons();
      });
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
    _controller.removeListener(_updateScrollButtons);
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_rowFocusNode.hasFocus) return;
          final firstFocusable = _getFirstFocusableNode();
          if (firstFocusable != null) {
            firstFocusable.requestFocus();
            _lastFocusedNode = firstFocusable;
            if (_controller.hasClients && _controller.position.pixels > 0) {
              _controller.jumpTo(0.0);
            }
          }
        });
      }
      _wasFocused = true;
    } else if (!hasFocus) {
      _wasFocused = false;
    }
  }

  void _updateScrollButtons() {
    if (!mounted || !_controller.hasClients) return;

    final canLeft = _controller.position.pixels > 0;
    final canRight =
        _controller.position.pixels < _controller.position.maxScrollExtent;

    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _scrollLeft() {
    if (!_controller.hasClients) return;
    final viewportWidth = _controller.position.viewportDimension;
    final offset = _controller.position.pixels - (viewportWidth * 0.8);
    _controller.animateTo(
      offset.clamp(0.0, _controller.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollRight() {
    if (!_controller.hasClients) return;
    final viewportWidth = _controller.position.viewportDimension;
    final offset = _controller.position.pixels + (viewportWidth * 0.8);
    _controller.animateTo(
      offset.clamp(0.0, _controller.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildArrowButtons() {
    if (_controller.hasClients && _controller.position.maxScrollExtent == 0) {
      return const SizedBox.shrink();
    }

    final isMobile = Breakpoints.isCompact(context);
    if (isMobile) {
      return const SizedBox.shrink(); // mobile scrolls by swiping
    }

    return AnimatedOpacity(
      opacity: (_canScrollLeft || _canScrollRight) && _isHoveringList
          ? 1.0
          : 0.0,
      duration: const Duration(milliseconds: 200),
      // Mouse-only buttons: the D-pad scrolls by moving between cards.
      child: ExcludeFocus(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 28),
              onPressed: _canScrollLeft ? _scrollLeft : null,
              color: Colors.white,
              disabledColor: Colors.white24,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 20,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 28),
              onPressed: _canScrollRight ? _scrollRight : null,
              color: Colors.white,
              disabledColor: Colors.white24,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 20,
            ),
          ],
        ),
      ),
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

    return Focus(
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
    );
  }

  Widget _buildList({EdgeInsets? overridePadding}) {
    if (widget.itemCount == 0 && widget.emptyBuilder != null) {
      return widget.emptyBuilder!(context);
    }
    if (widget.itemCount == 0) return const SizedBox.shrink();

    final padding = overridePadding ?? widget.padding;
    final effectivePadding = padding.copyWith(bottom: padding.bottom + 16);

    final count = widget.itemCount;

    final list = widget.separatorBuilder != null
        ? ListView.separated(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: effectivePadding,
            cacheExtent: 9999,
            itemCount: count,
            separatorBuilder: widget.separatorBuilder!,
            itemBuilder: (context, index) =>
                _buildTrackedItem(context, index, count),
          )
        : ListView.builder(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: effectivePadding,
            cacheExtent: 9999,
            itemCount: count,
            itemBuilder: (context, index) =>
                _buildTrackedItem(context, index, count),
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

    Widget content;

    switch (widget.theme) {
      case CarouselTheme.bentoBox:
        content = BentoBox(
          title: widget.title ?? '',
          icon: widget.icon,
          action: widget.headerAction != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    widget.headerAction!,
                    const SizedBox(width: 8),
                    _buildArrowButtons(),
                  ],
                )
              : _buildArrowButtons(),
          child: _buildList(),
        );
        break;

      case CarouselTheme.profileRow:
        final isMobile = Breakpoints.isCompact(context);
        final horizontalPadding = isMobile ? 16.0 : 24.0;
        final listPadding = widget.padding != EdgeInsets.zero
            ? widget.padding
            : EdgeInsets.symmetric(horizontal: horizontalPadding);

        content = ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.only(top: 24, bottom: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Row(
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Row(
                          children: [
                            if (widget.onHeaderTap != null)
                              InkWell(
                                mouseCursor: AppTheme.clickCursor,
                                onTap: widget.onHeaderTap,
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        widget.title ?? '',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.chevron_right,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Text(
                                widget.title ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                          ],
                        ),
                      ),
                      _buildArrowButtons(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildList(overridePadding: listPadding),
              ],
            ),
          ),
        );
        break;

      case CarouselTheme.homeRow:
        final isMobile = Breakpoints.isCompact(context);
        final horizontalPadding = widget.padding.left > 0
            ? widget.padding.left
            : (isMobile ? 16.0 : 24.0);
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                isMobile ? 4 : 8,
                horizontalPadding,
                isMobile ? 8 : 16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (widget.onHeaderTap != null)
                          InkWell(
                            mouseCursor: AppTheme.clickCursor,
                            onTap: widget.onHeaderTap,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.title ?? '',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium!
                                        .copyWith(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                    size: 24,
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Text(
                            widget.title ?? '',
                            style: Theme.of(context).textTheme.bodyMedium!
                                .copyWith(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                      ],
                    ),
                  ),
                  _buildArrowButtons(),
                ],
              ),
            ),
            _buildList(),
          ],
        );
        break;

      case CarouselTheme.plain:
        content = _buildList();
        break;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHoveringList = true),
      onExit: (_) => setState(() => _isHoveringList = false),
      child: content,
    );
  }
}
