import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/shared/widgets/hover_scale.dart';

void main() {
  testWidgets('HoverScale responds to tap and keyboard activation', (
    tester,
  ) async {
    int taps = 0;
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HoverScale(
            focusNode: focusNode,
            autofocus: true,
            onTap: () => taps++,
            child: const Text('Hover Target'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap
    await tester.tap(find.text('Hover Target'));
    await tester.pumpAndSettle();
    expect(taps, equals(1));

    // Keyboard activation
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(taps, equals(2));

    focusNode.dispose();
  });

  testWidgets('HoverScale animates scale on focus', (tester) async {
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HoverScale(
            focusNode: focusNode,
            scale: 1.2,
            child: const Text('Scale Target'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initially scale is 1.0
    AnimatedScale scaleWidget = tester.widget<AnimatedScale>(
      find.byType(AnimatedScale),
    );
    expect(scaleWidget.scale, equals(1.0));

    // Gain focus
    focusNode.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    scaleWidget = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scaleWidget.scale, equals(1.2));

    focusNode.dispose();
  });
}
