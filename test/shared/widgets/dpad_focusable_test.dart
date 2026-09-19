import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

void main() {
  testWidgets('DpadFocusable triggers onTap on tap', (tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DpadFocusable(
            onTap: () => tapped = true,
            child: const Text('Item 1'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Item 1'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('DpadFocusable activates via Enter, Select, Space, and Gamepad A', (tester) async {
    int activations = 0;
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DpadFocusable(
            focusNode: focusNode,
            autofocus: true,
            onTap: () => activations++,
            child: const Text('Focus Target'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(focusNode.hasFocus, isTrue);

    // Test Enter
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(activations, equals(1));

    // Test Select (standard TV D-Pad center)
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(activations, equals(2));

    // Test Space
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(activations, equals(3));

    // Test GameButtonA
    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
    await tester.pumpAndSettle();
    expect(activations, equals(4));

    focusNode.dispose();
  });

  testWidgets('DpadFocusable triggers onLongPress via ContextMenu and GameButtonX', (tester) async {
    int contextTriggers = 0;
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DpadFocusable(
            focusNode: focusNode,
            autofocus: true,
            onLongPress: () => contextTriggers++,
            child: const Text('Target'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pumpAndSettle();
    expect(contextTriggers, equals(1));

    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonX);
    await tester.pumpAndSettle();
    expect(contextTriggers, equals(2));

    focusNode.dispose();
  });

  testWidgets('DpadFocusable reports focus change and displays focus ring', (tester) async {
    bool focusState = false;
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DpadFocusable(
            focusNode: focusNode,
            showFocusRing: true,
            onFocusChange: (val) => focusState = val,
            child: const SizedBox(width: 100, height: 100, child: Text('Card')),
          ),
        ),
      ),
    );

    expect(focusState, isFalse);
    expect(find.byType(DecoratedBox), findsNothing);

    focusNode.requestFocus();
    await tester.pumpAndSettle();

    expect(focusState, isTrue);
    expect(find.byType(DecoratedBox), findsOneWidget);

    focusNode.dispose();
  });
}
