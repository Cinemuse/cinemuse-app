import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Right-clicks at [at] and lets the menu open.
Future<void> rightClickAt(WidgetTester tester, Offset at) async {
  await tester.tapAt(at, buttons: kSecondaryButton);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// The open popup menu's items, top to bottom.
final menuItems = find.byWidgetPredicate((w) => w is PopupMenuItem);

/// The menu opens at [at] (REV-248): its first item starts there, below the
/// menu's top padding, to the right of [at] on the left half of the screen
/// and to its left on the right half.
void expectMenuAt(WidgetTester tester, Offset at) {
  final first = tester.getRect(menuItems.first);
  expect(
    at.dx,
    anyOf(
      moreOrLessEquals(first.left, epsilon: 1),
      moreOrLessEquals(first.right, epsilon: 1),
    ),
  );
  expect(first.top - at.dy, inInclusiveRange(0, 16));
}
