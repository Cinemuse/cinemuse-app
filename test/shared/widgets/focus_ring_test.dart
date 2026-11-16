import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';

import '../../helpers/focus_helpers.dart';

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => const SizedBox(width: 50, height: 50);
}

void main() {
  // Showing the ring rebuilt the child from scratch: an open DropdownButton
  // menu closed as soon as the button took the focus.
  testWidgets('FocusRing: showing it keeps the child', (tester) async {
    Widget ring(bool isVisible) => Directionality(
      textDirection: TextDirection.ltr,
      child: FocusRing(isVisible: isVisible, child: const _Counter()),
    );
    await tester.pumpWidget(ring(false));
    tester.state<_CounterState>(find.byType(_Counter)).taps = 3;

    await tester.pumpWidget(ring(true));

    expect(tester.state<_CounterState>(find.byType(_Counter)).taps, 3);
  });

  // REV-252: Flutter's own widgets also take the focus on a click; the ring
  // is only for the keyboard / remote. Moving the mouse or its wheel hides
  // it too; only the keys that move or press bring it back, not typing,
  // Esc or Space (user, 2026-10-20). Each case starts after a key.
  Future<void> click(WidgetTester tester) => tester.tap(find.text('Row'));
  Future<void> key(WidgetTester tester, LogicalKeyboardKey key) async {
    await click(tester);
    await tester.sendKeyEvent(key);
  }

  Future<void> moveMouse(WidgetTester tester, double by) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveBy(Offset(by, 0));
  }

  final inputCases = <(String, Future<void> Function(WidgetTester), bool)>[
    ('a click', click, false),
    ('a click, then Tab', (t) => key(t, .tab), true),
    ('a click, then an arrow', (t) => key(t, .arrowDown), true),
    ('a click, then Enter', (t) => key(t, .enter), true),
    ('a click, then a letter', (t) => key(t, .keyA), false),
    ('a click, then Esc', (t) => key(t, .escape), false),
    ('a click, then Space', (t) => key(t, .space), false),
    ('the mouse moved', (t) => moveMouse(t, 20), false),
    ('the mouse bumped a little', (t) => moveMouse(t, 3), true),
    (
      'the mouse wheel',
      (t) async {
        final mouse = TestPointer(1, PointerDeviceKind.mouse);
        await t.sendEventToBinding(mouse.addPointer(location: Offset.zero));
        await t.sendEventToBinding(mouse.scroll(const Offset(0, 50)));
        addTearDown(() => t.sendEventToBinding(mouse.removePointer()));
      },
      false,
    ),
  ];
  for (final (name, input, isKeyInput) in inputCases) {
    testWidgets('FocusRing.isKeyInput after $name', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusRingFollower(
              child: InkWell(onTap: () {}, child: const Text('Row')),
            ),
          ),
        ),
      );

      FocusRing.debugWatchKeys();
      await input(tester);

      expect(FocusRing.isKeyInput.value, isKeyInput);
      expect(
        FocusManager.instance.highlightMode,
        isKeyInput ? FocusHighlightMode.traditional : FocusHighlightMode.touch,
      );
    });
  }

  // Flutter's own focus highlight stayed on a row after the ring had hidden;
  // the mouse's hover highlight must still show.
  testWidgets('an InkWell row: focus highlight with the ring, hover stays', (
    tester,
  ) async {
    const focusColor = Color(0xFF00FF00);
    const hoverColor = Color(0xFF0000FF);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: FocusRingFollower(
              child: InkWell(
                onTap: () {},
                focusColor: focusColor,
                hoverColor: hoverColor,
                child: const SizedBox(
                  width: 100,
                  height: 40,
                  child: Text('Row'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final ink = Material.of(tester.element(find.text('Row')));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(ink, paints..rect(color: focusColor));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveBy(const Offset(20, 0));
    await tester.pumpAndSettle();
    expect(ink, isNot(paints..rect(color: focusColor)));

    await mouse.moveTo(tester.getCenter(find.text('Row')));
    await tester.pumpAndSettle();
    expect(ink, paints..rect(color: hoverColor));
  });

  testWidgets('FocusRingFollower: ring while the InkWell inside has focus', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FocusRingFollower(
            child: InkWell(onTap: () {}, child: const Text('Row')),
          ),
        ),
      ),
    );
    final ring = find.byType(FocusRing);
    expect(tester.widget<FocusRing>(ring).isVisible, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(tester.widget<FocusRing>(ring).isVisible, isTrue);
  });

  // On the TV the theme's buttons only changed colour; now each draws the
  // ring, and a row around one shows only the button's (one ring, not two).
  testWidgets('the ring moves from a row to its button, never on both', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: FocusRingFollower(
            child: InkWell(
              onTap: () {},
              child: Row(
                children: [
                  const Text('Row'),
                  IconButton(
                    onPressed: () {},
                    tooltip: 'Remove',
                    icon: const Icon(Icons.delete),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    bool rowRing() =>
        tester.widget<FocusRing>(find.byType(FocusRing).first).isVisible;
    bool buttonRing() => tester
        .widget<FocusRing>(
          find.descendant(
            of: find.byType(ButtonFocusRing),
            matching: find.byType(FocusRing),
          ),
        )
        .isVisible;

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect((rowRing(), buttonRing()), (true, false));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect((rowRing(), buttonRing()), (false, true));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pump();
    expect(isFocused(find.text('Row')), isTrue);
    expect((rowRing(), buttonRing()), (true, false));
  });
}
