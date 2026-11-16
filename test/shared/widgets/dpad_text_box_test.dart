import 'package:cinemuse_app/shared/widgets/dpad_text_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/focus_helpers.dart';

void main() {
  Future<void> pumpBox(
    WidgetTester tester, {
    FocusNode? textFocusNode,
    VoidCallback? onBack,
    VoidCallback? onUp,
    VoidCallback? onDown,
    bool isMultiline = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DpadTextBox(
            textFocusNode: textFocusNode,
            onBack: onBack,
            onUp: onUp,
            onDown: onDown,
            isMultiline: isMultiline,
            builder: (context, textNode, stopTyping) => TextField(
              focusNode: textNode,
              maxLines: isMultiline ? null : 1,
              onEditingComplete: stopTyping,
            ),
          ),
        ),
      ),
    );
  }

  final box = find.byType(TextField);
  bool isTyping(WidgetTester tester) =>
      tester.widget<TextField>(box).focusNode!.hasFocus;

  /// Reaches the box the way the arrows do, not by clicking it.
  Future<void> arrowToBox(WidgetTester tester) async {
    await tabTo(tester, box);
    expect(isTyping(tester), isFalse);
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump();
  }

  testWidgets('the arrows stop on the box with no keyboard; Enter starts '
      'typing, Enter or Back stops it and keeps the text', (tester) async {
    await pumpBox(tester);

    await arrowToBox(tester);
    expect(tester.testTextInput.isVisible, isFalse);

    await press(tester, LogicalKeyboardKey.enter);
    expect(isTyping(tester), isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    tester.testTextInput.enterText('Rai');
    await tester.pump();

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(isTyping(tester), isFalse);
    expect(isFocused(box), isTrue);
    expect(find.widgetWithText(TextField, 'Rai'), findsOneWidget);

    await press(tester, LogicalKeyboardKey.select);
    expect(isTyping(tester), isTrue);
    await press(tester, LogicalKeyboardKey.escape);
    expect(isTyping(tester), isFalse);
    expect(isFocused(box), isTrue);
  });

  testWidgets('a click types at once', (tester) async {
    await pumpBox(tester);

    await tester.tap(box);
    await tester.pump();
    expect(isTyping(tester), isTrue);
  });

  testWidgets('focusing the text from outside types at once (a box that '
      'opens to be typed in)', (tester) async {
    final textNode = FocusNode();
    addTearDown(textNode.dispose);
    await pumpBox(tester, textFocusNode: textNode);

    textNode.requestFocus();
    await tester.pump();
    expect(isTyping(tester), isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('Up and Down leave the box, typing or not', (tester) async {
    var ups = 0;
    var downs = 0;
    await pumpBox(tester, onUp: () => ups++, onDown: () => downs++);

    await arrowToBox(tester);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect((ups, downs), (1, 1));

    await press(tester, LogicalKeyboardKey.enter);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect((ups, downs), (2, 2));
  });

  testWidgets('a box of many lines keeps Up and Down while typing', (
    tester,
  ) async {
    var moves = 0;
    await pumpBox(
      tester,
      onUp: () => moves++,
      onDown: () => moves++,
      isMultiline: true,
    );

    await arrowToBox(tester);
    await press(tester, LogicalKeyboardKey.enter);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(moves, 0);
    expect(isTyping(tester), isTrue);
  });

  testWidgets('Back on the box goes to onBack; while typing it only stops '
      'typing', (tester) async {
    var backs = 0;
    await pumpBox(tester, onBack: () => backs++);

    await arrowToBox(tester);
    await press(tester, LogicalKeyboardKey.escape);
    expect(backs, 1);

    await press(tester, LogicalKeyboardKey.enter);
    await press(tester, LogicalKeyboardKey.escape);
    expect(backs, 1);
    expect(isTyping(tester), isFalse);
  });
}
