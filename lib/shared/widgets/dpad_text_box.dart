import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';
import 'package:cinemuse_app/shared/widgets/state_preview.dart';

/// Builds the text field inside a [DpadTextBox]: it must use [textNode] as
/// its focus node and call [stopTyping] from `onEditingComplete`, so the
/// keyboard's Done or Search keeps the box focused instead of dropping it.
typedef DpadTextFieldBuilder =
    Widget Function(
      BuildContext context,
      FocusNode textNode,
      VoidCallback stopTyping,
    );

/// A text box that the arrows treat as a stop like a button: passing over
/// it opens no keyboard (on a TV the keyboard covers the screen). Enter
/// starts typing; Enter or Back stops it and keeps the text, Up and Down
/// stop it and move on. A click or a tap types at once, and so does
/// focusing [textFocusNode] (a box that opens to be typed in).
class DpadTextBox extends StatefulWidget {
  /// The box as an arrow stop, so the row around it can focus it.
  final FocusNode? focusNode;

  /// The text itself: focusing it starts typing, and a box before this one
  /// moves to it with the keyboard's Next.
  final FocusNode? textFocusNode;

  /// Back on the box while not typing; without it, Back goes to the page.
  final VoidCallback? onBack;

  /// Up from the box; without it, focus moves to what is above.
  final VoidCallback? onUp;

  /// Down from the box; without it, focus moves to what is below.
  final VoidCallback? onDown;

  /// Left from the box; without it, focus moves to what is beside.
  final VoidCallback? onLeft;

  /// Right from the box; without it, focus moves to what is beside.
  final VoidCallback? onRight;

  /// A box of many lines: while typing, Up and Down move the cursor.
  final bool isMultiline;

  /// The box's own corner radius, for the focus ring.
  final BorderRadius borderRadius;

  final DpadTextFieldBuilder builder;

  const DpadTextBox({
    super.key,
    this.focusNode,
    this.textFocusNode,
    this.onBack,
    this.onUp,
    this.onDown,
    this.onLeft,
    this.onRight,
    this.isMultiline = false,
    this.borderRadius = AppTheme.radiusMd,
    required this.builder,
  });

  @override
  State<DpadTextBox> createState() => _DpadTextBoxState();
}

class _DpadTextBoxState extends State<DpadTextBox> {
  final _ownBoxNode = FocusNode(debugLabel: 'DpadTextBox');
  final _ownTextNode = FocusNode(debugLabel: 'DpadTextBoxText');

  FocusNode get _boxNode => widget.focusNode ?? _ownBoxNode;
  FocusNode get _textNode => widget.textFocusNode ?? _ownTextNode;

  @override
  void initState() {
    super.initState();
    _attachText(_textNode);
    // Rebuild so the ring follows the focus.
    _boxNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(DpadTextBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldBoxNode = oldWidget.focusNode ?? _ownBoxNode;
    if (oldBoxNode != _boxNode) {
      oldBoxNode.removeListener(_onFocusChange);
      _boxNode.addListener(_onFocusChange);
    }
    final oldTextNode = oldWidget.textFocusNode ?? _ownTextNode;
    if (oldTextNode != _textNode) {
      oldTextNode.onKeyEvent = null;
      _attachText(_textNode);
    }
  }

  @override
  void dispose() {
    _boxNode.removeListener(_onFocusChange);
    _textNode.onKeyEvent = null;
    _ownBoxNode.dispose();
    _ownTextNode.dispose();
    super.dispose();
  }

  // The arrows never land on the text itself: only Enter on the box, a
  // click or a tap start typing, so the keyboard opens only then.
  void _attachText(FocusNode node) {
    node.skipTraversal = true;
    node.onKeyEvent = _onTypingKey;
  }

  void _onFocusChange() => setState(() {});

  void _stopTyping() => _boxNode.requestFocus();

  /// With nothing that way the key goes on to the page: Up at the top of a
  /// page reaches the navbar.
  KeyEventResult _move(VoidCallback? callback, TraversalDirection direction) {
    if (callback != null) {
      callback();
      return KeyEventResult.handled;
    }
    return _boxNode.focusInDirection(direction)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  static bool _isBack(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.escape ||
      key == LogicalKeyboardKey.gameButtonB ||
      key == LogicalKeyboardKey.goBack;

  /// Keys on the box while not typing.
  KeyEventResult _onBoxKey(FocusNode node, KeyEvent event) {
    // While typing, the keys belong to the text.
    if (!node.hasPrimaryFocus) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.gameButtonA)) {
      _textNode.requestFocus();
      return KeyEventResult.handled;
    }
    if (_isBack(key)) {
      final onBack = widget.onBack;
      if (onBack == null) return KeyEventResult.ignored;
      onBack();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      return _move(widget.onUp, TraversalDirection.up);
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      return _move(widget.onDown, TraversalDirection.down);
    }
    final side = switch (key) {
      LogicalKeyboardKey.arrowLeft => widget.onLeft,
      LogicalKeyboardKey.arrowRight => widget.onRight,
      _ => null,
    };
    if (side == null) return KeyEventResult.ignored;
    side();
    return KeyEventResult.handled;
  }

  /// Keys while typing; Left and Right move the cursor.
  KeyEventResult _onTypingKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (_isBack(key)) {
      _stopTyping();
      return KeyEventResult.handled;
    }
    if (widget.isMultiline) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowUp) {
      return _move(widget.onUp, TraversalDirection.up);
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      return _move(widget.onDown, TraversalDirection.down);
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return FocusRing(
      // A brand page preview shows the ring without a key press.
      isVisible:
          _boxNode.hasPrimaryFocus ||
          (StatePreview.maybeOf(context)?.isFocused ?? false),
      borderRadius: widget.borderRadius,
      child: Focus(
        focusNode: _boxNode,
        onKeyEvent: _onBoxKey,
        child: widget.builder(context, _textNode, _stopTyping),
      ),
    );
  }
}
