import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';

bool isRingShown(WidgetTester tester) => tester
    .widgetList<FocusRing>(find.byType(FocusRing))
    .any((ring) => ring.isVisible);

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

  testWidgets(
    'DpadFocusable activates via Enter, Select, Space, and Gamepad A',
    (tester) async {
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
    },
  );

  testWidgets(
    'DpadFocusable triggers onLongPress via ContextMenu and GameButtonX',
    (tester) async {
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

      // Shift+F10: the Windows shortcut for the context menu (REV-284).
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(contextTriggers, equals(3));

      focusNode.dispose();
    },
  );

  // REV-284: a keyboard / TV remote has no long press, only key repeats.
  for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.select]) {
    testWidgets('DpadFocusable: ${key.keyLabel} held = long press, '
        'pressed = tap', (tester) async {
      var taps = 0;
      var longPresses = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DpadFocusable(
              autofocus: true,
              onTap: () => taps++,
              onLongPress: () => longPresses++,
              child: const Text('Target'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
      expect((taps, longPresses), (1, 0));

      await tester.sendKeyDownEvent(key);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 60));
        await tester.sendKeyRepeatEvent(key);
      }
      await tester.sendKeyUpEvent(key);
      await tester.pumpAndSettle();
      expect((taps, longPresses), (1, 1));
    });
  }

  testWidgets('DpadFocusable reports focus change and displays focus ring', (
    tester,
  ) async {
    bool focusState = false;
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DpadFocusable(
            focusNode: focusNode,
            onFocusChange: (val) => focusState = val,
            child: const SizedBox(width: 100, height: 100, child: Text('Card')),
          ),
        ),
      ),
    );

    expect(focusState, isFalse);
    expect(isRingShown(tester), isFalse);

    focusNode.requestFocus();
    await tester.pumpAndSettle();

    expect(focusState, isTrue);
    expect(isRingShown(tester), isTrue);

    focusNode.dispose();
  });

  // REV-252: the mouse only grows an item; the keyboard / remote also adds
  // the ring, so with both on screen the ringed one is what Enter opens.
  for (final hasBuilder in [false, true]) {
    testWidgets('DpadFocusable: hover grows, focus grows + ring '
        '(${hasBuilder ? 'own look' : 'plain child'})', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DpadFocusable(
                focusNode: focusNode,
                onTap: () {},
                scale: 1.05,
                builder: hasBuilder
                    ? (context, isFocused, isHovered, child) => child
                    : null,
                child: const SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      );
      final item = find.byType(DpadFocusable);
      double scale() => tester
          .widget<AnimatedScale>(
            find.descendant(of: item, matching: find.byType(AnimatedScale)),
          )
          .scale;

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(item));
      await tester.pumpAndSettle();
      expect((scale(), isRingShown(tester)), (1.05, false));

      await mouse.moveTo(Offset.zero);
      focusNode.requestFocus();
      await tester.pumpAndSettle();
      expect((scale(), isRingShown(tester)), (1.05, true));
    });
  }

  testWidgets('DpadFocusable shows its tooltip on hover (REV-253)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DpadFocusable(
              tooltip: 'Remove filter',
              onTap: () {},
              child: const Icon(Icons.close),
            ),
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byIcon(Icons.close)));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Remove filter'), findsOneWidget);
  });

  // REV-251: Item 0 has the keyboard focus, then the mouse wheel scrolls the
  // page down. Focus handed back to Item 0 must not jump the page up again;
  // a key that moves the focus still scrolls to it.
  final restoreCases = <(String, Future<void> Function(WidgetTester), bool)>[
    (
      'menu closed by a click',
      (tester) async {
        await tester.tap(find.text('Item 16'), buttons: kSecondaryButton);
        await tester.pumpAndSettle();
        expect(find.text('Menu entry'), findsOneWidget);
        await tester.tapAt(const Offset(780, 580));
        await tester.pumpAndSettle();
        expect(find.text('Menu entry'), findsNothing);
      },
      false,
    ),
    (
      'window back after Alt+Tab',
      (tester) async {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pumpAndSettle();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
      },
      false,
    ),
    (
      'Tab to the next item',
      (tester) async {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
      },
      true,
    ),
  ];
  for (final (name, action, shouldScroll) in restoreCases) {
    testWidgets(
      'DpadFocusable: page scroll after $name (REV-251)',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                controller: controller,
                child: Column(
                  children: [
                    for (var i = 0; i < 30; i++)
                      Builder(
                        builder: (context) => DpadFocusable(
                          onTap: () {},
                          onSecondaryTapDown: (d) => showMenu<void>(
                            context: context,
                            position: RelativeRect.fromLTRB(
                              d.globalPosition.dx,
                              d.globalPosition.dy,
                              0,
                              0,
                            ),
                            items: const [
                              PopupMenuItem(child: Text('Menu entry')),
                            ],
                          ),
                          child: SizedBox(height: 100, child: Text('Item $i')),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        FocusRing.debugWatchKeys();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<DpadFocusable>()
              ?.child,
          isA<SizedBox>(),
        );

        // The mouse wheel: scrolls without moving the focus.
        controller.jumpTo(1500);
        await tester.pumpAndSettle();
        expect(controller.offset, 1500);

        await action(tester);

        expect(controller.offset, shouldScroll ? lessThan(1500) : 1500);
        // Flutter hands the focus back after Alt+Tab on desktop only.
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}
