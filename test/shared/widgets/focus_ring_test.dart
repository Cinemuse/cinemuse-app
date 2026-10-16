import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';

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
  // is only for the keyboard / remote.
  testWidgets('FocusRing.isKeyInput: off after a click, on after a key', (
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

    FocusRing.debugWatchKeys();
    await tester.tap(find.text('Row'));
    final afterClick = FocusRing.isKeyInput.value;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);

    expect(afterClick, isFalse);
    expect(FocusRing.isKeyInput.value, isTrue);
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
}
