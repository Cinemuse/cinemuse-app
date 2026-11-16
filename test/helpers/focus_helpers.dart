import 'package:cinemuse_app/shared/widgets/focus_ring.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
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

/// Presses Tab through every stop of the screen, once round, and names
/// the ones that show no [FocusRing] (empty when every stop shows it).
/// Call `FocusRing.debugWatchKeys()` first.
Future<List<String>> stopsWithoutRing(
  WidgetTester tester, {
  int max = 80,
}) async {
  bool showsRing(BuildContext focused) {
    final self = find.byElementPredicate((e) => e == focused);
    final ring = find.byWidgetPredicate((w) => w is FocusRing && w.isVisible);
    return find.ancestor(of: self, matching: ring).evaluate().isNotEmpty ||
        find.descendant(of: self, matching: ring).evaluate().isNotEmpty;
  }

  final seen = <FocusNode>{};
  final withoutRing = <String>[];
  for (var i = 0; i < max; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final node = FocusManager.instance.primaryFocus;
    if (node == null || node is FocusScopeNode) continue;
    if (!seen.add(node)) break;
    if (!showsRing(node.context!)) {
      withoutRing.add(node.context!.widget.toStringShort());
      final tooltip = node.context!
          .findAncestorWidgetOfExactType<Tooltip>()
          ?.message;
      if (tooltip != null) withoutRing.add('($tooltip)');
    }
  }
  return withoutRing;
}
