import 'package:flutter/material.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';

/// A [PopupMenuItem] whose row gets the [FocusRing] while it has the
/// keyboard / remote focus. Use it in place of [PopupMenuItem].
class AppPopupMenuItem<T> extends PopupMenuItem<T> {
  const AppPopupMenuItem({
    super.key,
    super.value,
    super.onTap,
    super.enabled,
    super.height,
    super.padding,
    super.textStyle,
    super.labelTextStyle,
    super.mouseCursor,
    required super.child,
  });

  @override
  PopupMenuItemState<T, AppPopupMenuItem<T>> createState() =>
      _AppPopupMenuItemState<T>();
}

class _AppPopupMenuItemState<T>
    extends PopupMenuItemState<T, AppPopupMenuItem<T>> {
  @override
  Widget? buildChild() => _MenuRowFocusRing(child: super.buildChild());
}

/// [items] of a DropdownButton, each open-menu row with the [FocusRing]
/// while it has the keyboard / remote focus.
List<DropdownMenuItem<T>> withMenuFocusRings<T>(
  List<DropdownMenuItem<T>> items,
) => [
  for (final item in items)
    DropdownMenuItem<T>(
      value: item.value,
      onTap: item.onTap,
      enabled: item.enabled,
      alignment: item.alignment,
      child: _MenuRowFocusRing(child: item.child),
    ),
];

/// In an open menu: fills the row's width and shows the ring while the row
/// has the focus. In the closed DropdownButton, which shows the same child
/// as its value, it changes nothing.
class _MenuRowFocusRing extends StatelessWidget {
  final Widget? child;

  const _MenuRowFocusRing({required this.child});

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    // Menus open in a PopupRoute; sheets and dialogs are PopupRoutes too.
    final isInMenu =
        route is PopupRoute &&
        route is! ModalBottomSheetRoute &&
        route is! RawDialogRoute;
    if (!isInMenu) return child ?? const SizedBox.shrink();
    return FocusRing(
      // The row's own InkWell is the nearest focus node.
      isVisible: Focus.of(context).hasFocus,
      child: SizedBox(width: double.infinity, child: child),
    );
  }
}
