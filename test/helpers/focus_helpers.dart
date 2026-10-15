import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether the focused control is the one showing [target] (its text, icon
/// or spinner). Read through `primaryFocus`, not the `Focus` tree, so layout
/// changes don't break it.
bool isFocused(Finder target) {
  final node = FocusManager.instance.primaryFocus;
  // A focused page or dialog contains everything: no control has focus.
  if (node == null || node is FocusScopeNode) return false;
  bool shows(BuildContext? context) =>
      context != null &&
      find
          .descendant(
            of: find.byElementPredicate((e) => e == context),
            matching: target,
          )
          .evaluate()
          .isNotEmpty;
  if (!shows(node.context)) return false;
  // A focusable control inside the focused one (e.g. a button on a focused
  // card) owns [target] instead.
  return !node.descendants.any(
    (d) => d.canRequestFocus && !d.skipTraversal && shows(d.context),
  );
}

/// Presses Tab until the control showing [target] has the focus.
Future<void> tabTo(WidgetTester tester, Finder target, {int max = 20}) async {
  for (var i = 0; i < max && !isFocused(target); i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  expect(isFocused(target), isTrue, reason: 'Tab never reached $target');
}
