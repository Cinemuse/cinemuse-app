import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/bento_box.dart';

enum CarouselTheme {
  homeRow,     // Title + chevron right (no box)
  profileRow,  // Icon + Title + chevron right inside a container with surface color
  bentoBox,    // BentoBox with title and icon
  plain,       // No header
}

class GenericCarouselRow extends StatefulWidget {
  final String? title;
  final IconData? icon;
  final CarouselTheme theme;
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final Widget Function(BuildContext context, int index)? separatorBuilder;
  final WidgetBuilder? emptyBuilder;
  final double? height;
  final EdgeInsets padding;
  final ScrollController? controller;
  
  const GenericCarouselRow({
    super.key,
    this.title,
    this.icon,
    this.theme = CarouselTheme.plain,
    required this.itemCount,
    required this.itemBuilder,
    this.separatorBuilder,
    this.emptyBuilder,
    this.height,
    this.padding = EdgeInsets.zero,
    this.controller,
  });

  @override
  State<GenericCarouselRow> createState() => _GenericCarouselRowState();
}

class _GenericCarouselRowState extends State<GenericCarouselRow> {
  late ScrollController _controller;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;
  bool _isHoveringList = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ScrollController();
    _controller.addListener(_updateScrollButtons);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollButtons();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_updateScrollButtons);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _updateScrollButtons() {
    if (!mounted || !_controller.hasClients) return;
    
    final canLeft = _controller.position.pixels > 0;
    final canRight = _controller.position.pixels < _controller.position.maxScrollExtent;
    
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
    
    final isMobile = MediaQuery.of(context).size.width < 600;
    if (isMobile) {
        return const SizedBox.shrink(); // hide on mobile natively
    }

    return AnimatedOpacity(
      opacity: (_canScrollLeft || _canScrollRight) && _isHoveringList ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
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
    );
  }

  Widget _buildList() {
    if (widget.itemCount == 0 && widget.emptyBuilder != null) {
      return widget.emptyBuilder!(context);
    }
    if (widget.itemCount == 0) return const SizedBox.shrink();

    final effectivePadding = widget.padding.copyWith(
      bottom: widget.padding.bottom + 16,
    );

    final list = widget.separatorBuilder != null
        ? ListView.separated(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: effectivePadding,
            cacheExtent: 9999,
            itemCount: widget.itemCount,
            separatorBuilder: widget.separatorBuilder!,
            itemBuilder: widget.itemBuilder,
          )
        : ListView.builder(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: effectivePadding,
            cacheExtent: 9999,
            itemCount: widget.itemCount,
            itemBuilder: widget.itemBuilder,
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
          left: widget.padding.left,
          right: widget.padding.right,
        ), 
        child: list,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0 && widget.emptyBuilder == null) return const SizedBox.shrink();

    Widget content;

    switch (widget.theme) {
      case CarouselTheme.bentoBox:
        content = BentoBox(
          title: widget.title ?? '',
          icon: widget.icon,
          action: _buildArrowButtons(),
          child: _buildList(),
        );
        break;

      case CarouselTheme.profileRow:
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
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          widget.title ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      _buildArrowButtons(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildList(),
              ],
            ),
          ),
        );
        break;

      case CarouselTheme.homeRow:
        final horizontalPadding = widget.padding.left > 0 ? widget.padding.left : 24.0;
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          widget.title ?? '',
                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right, color: AppTheme.textMuted),
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
