import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The mouse cursor shown with the mouse over the middle of [finder].
Future<MouseCursor> cursorOver(WidgetTester tester, Finder finder) async {
  final gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    pointer: 1,
  );
  await gesture.addPointer(location: tester.getCenter(finder.first));
  await tester.pump();
  final cursor = RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(
    1,
  )!;
  await gesture.removePointer();
  await tester.pump();
  return cursor;
}

/// The hand cursor is shown over [finder] (REV-246).
Future<void> expectHandOver(WidgetTester tester, Finder finder) async {
  expect(
    await cursorOver(tester, finder),
    SystemMouseCursors.click,
    reason: '$finder',
  );
}
