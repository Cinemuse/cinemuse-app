import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';
import 'package:cinemuse_app/shared/widgets/pointer_hiding_layer.dart';

void main() {
  // The mouse pointer sat in the middle of the screen while the arrows moved
  // the focus: it hides after an arrow and comes back when the mouse moves.
  testWidgets('PointerHidingLayer: no pointer or tooltip while keys are in '
      'use; a click still works', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => PointerHidingLayer(child: child!),
        home: Scaffold(
          body: Center(
            child: DpadFocusable(
              tooltip: 'Remove filter',
              onTap: () => taps++,
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      ),
    );
    final button = find.byType(DpadFocusable);
    final mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      pointer: 1,
    );
    await mouse.addPointer(location: tester.getCenter(button));
    addTearDown(mouse.removePointer);
    MouseCursor? cursor() =>
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1);

    FocusRing.debugWatchKeys();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(cursor(), SystemMouseCursors.none);
    expect(find.text('Remove filter'), findsNothing);

    await mouse.moveBy(const Offset(20, 0));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(cursor(), SystemMouseCursors.click);
    expect(find.text('Remove filter'), findsOne);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await mouse.down(tester.getCenter(button));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}
