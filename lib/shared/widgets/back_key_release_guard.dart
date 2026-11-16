import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Wraps the whole app so one Back on a remote is one Back.
///
/// The app acts on the Back key's press, but Android acts on its release: a
/// release the app leaves alone goes back to Android, which turns it into a
/// second Back (on the Fire Stick every Back counted twice). Above every
/// focus, this sees only the keys nothing below used: a press that got here
/// was not used, so its release goes on to Android as before; the release of
/// a press the app used is claimed here.
class BackKeyReleaseGuard extends StatefulWidget {
  final Widget child;

  const BackKeyReleaseGuard({super.key, required this.child});

  @override
  State<BackKeyReleaseGuard> createState() => _BackKeyReleaseGuardState();
}

class _BackKeyReleaseGuardState extends State<BackKeyReleaseGuard> {
  /// Back keys whose press nothing in the app used.
  final _unusedPresses = <LogicalKeyboardKey>{};

  static bool _isBack(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.gameButtonB;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (!_isBack(key)) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      _unusedPresses.add(key);
      return KeyEventResult.ignored;
    }
    if (event is KeyUpEvent && !_unusedPresses.remove(key)) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: widget.child,
    );
  }
}
