import 'package:flutter/material.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';

/// Wraps the whole app: while the keyboard / remote is in use
/// ([FocusRing.isKeyInput]) the mouse pointer is hidden and no tooltip opens
/// under it, so it doesn't sit over the screen the arrows move through.
/// Moving the mouse brings both back where the pointer was.
class PointerHidingLayer extends StatelessWidget {
  final Widget child;

  const PointerHidingLayer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: FocusRing.isKeyInput,
      child: child,
      builder: (context, isKeyInput, child) => TooltipVisibility(
        visible: !isKeyInput,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            child!,
            // On top, so its cursor beats the hand cursors below. Not opaque:
            // it is never what a click hits, so the first click after the
            // arrows still reaches the item under the pointer.
            Positioned.fill(
              child: MouseRegion(
                opaque: false,
                cursor: isKeyInput
                    ? SystemMouseCursors.none
                    : MouseCursor.defer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
