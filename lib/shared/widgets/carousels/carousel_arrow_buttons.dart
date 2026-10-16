import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The ← / → mouse buttons of a carousel row, shown while the mouse is over
/// the row. They follow the scroll and the hover on their own, so neither
/// rebuilds the row and its cards (REV-41).
class CarouselArrowButtons extends StatefulWidget {
  final ScrollController controller;
  final ValueListenable<bool> isHovering;
  final void Function({required bool isForward}) onStep;

  const CarouselArrowButtons({
    super.key,
    required this.controller,
    required this.isHovering,
    required this.onStep,
  });

  @override
  State<CarouselArrowButtons> createState() => _CarouselArrowButtonsState();
}

class _CarouselArrowButtonsState extends State<CarouselArrowButtons> {
  bool _canScrollLeft = false;
  bool _canScrollRight = false;
  bool _hasOverflow = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
    _updateAfterLayout();
  }

  @override
  void didUpdateWidget(CarouselArrowButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_update);
      widget.controller.addListener(_update);
    }
    // The row rebuilt (new items, new size): the scroll range may have changed.
    _updateAfterLayout();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    super.dispose();
  }

  // The list's scroll range is known only after it is laid out.
  void _updateAfterLayout() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _update());

  void _update() {
    final controller = widget.controller;
    if (!mounted || !controller.hasClients) return;
    final position = controller.position;
    final canLeft = position.pixels > 0;
    final canRight = position.pixels < position.maxScrollExtent;
    final hasOverflow = position.maxScrollExtent > 0;
    if (canLeft != _canScrollLeft ||
        canRight != _canScrollRight ||
        hasOverflow != _hasOverflow) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
        _hasOverflow = hasOverflow;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mobile scrolls by swiping.
    if (!_hasOverflow || Breakpoints.isCompact(context)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;

    return ValueListenableBuilder<bool>(
      valueListenable: widget.isHovering,
      builder: (context, isHovering, child) => AnimatedOpacity(
        opacity: (_canScrollLeft || _canScrollRight) && isHovering ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: child,
      ),
      // Mouse-only buttons: the D-pad scrolls by moving between cards.
      child: ExcludeFocus(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ArrowButton(
              tooltip: l10n.commonScrollLeft,
              icon: Icons.chevron_left,
              onPressed: _canScrollLeft
                  ? () => widget.onStep(isForward: false)
                  : null,
            ),
            const SizedBox(width: 8),
            _ArrowButton(
              tooltip: l10n.commonScrollRight,
              icon: Icons.chevron_right,
              onPressed: _canScrollRight
                  ? () => widget.onStep(isForward: true)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _ArrowButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 28),
      onPressed: onPressed,
      color: Colors.white,
      disabledColor: Colors.white24,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      splashRadius: 20,
    );
  }
}
