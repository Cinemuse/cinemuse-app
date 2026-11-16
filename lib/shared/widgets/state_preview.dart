import 'package:flutter/widgets.dart';

/// Shows the widgets below as hovered and / or focused without a mouse or
/// a key: for the brand showcase (`cinemuse-design`), which lays every
/// state side by side. The app never puts one in its tree, so it changes
/// nothing there. Read by `DpadFocusable`, `FocusRing` and
/// `SettingsTextField`.
class StatePreview extends InheritedWidget {
  final bool isHovered;
  final bool isFocused;

  const StatePreview({
    super.key,
    this.isHovered = false,
    this.isFocused = false,
    required super.child,
  });

  /// No preview above: both false, the widget follows the real mouse / key.
  static StatePreview? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StatePreview>();

  @override
  bool updateShouldNotify(StatePreview oldWidget) =>
      oldWidget.isHovered != isHovered || oldWidget.isFocused != isFocused;
}

/// A focus node that always says it has the focus: gives a `TextField` its
/// focused look under a [StatePreview], where many are shown at once and
/// only one could really have the focus.
class PreviewFocusNode extends FocusNode {
  PreviewFocusNode() : super(canRequestFocus: false, skipTraversal: true);

  @override
  bool get hasFocus => true;
}
