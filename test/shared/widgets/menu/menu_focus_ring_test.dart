import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';
import 'package:cinemuse_app/shared/widgets/menu/menu_focus_ring.dart';

/// The texts whose [FocusRing] is shown.
List<String> ringedTexts(WidgetTester tester) => [
  for (final ring in tester.widgetList<FocusRing>(find.byType(FocusRing)))
    if (ring.isVisible)
      ...tester
          .widgetList<Text>(
            find.descendant(
              of: find.byWidget(ring),
              matching: find.byType(Text),
            ),
          )
          .map((text) => text.data!),
];

void main() {
  // REV-252: menu rows get the app's ring via the keyboard.
  testWidgets('withMenuFocusRings: ring on the focused row of the open '
      'dropdown, none on the closed button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DropdownButton<int>(
            value: 1,
            onChanged: (_) {},
            items: withMenuFocusRings([
              const DropdownMenuItem(value: 1, child: Text('One')),
              const DropdownMenuItem(value: 2, child: Text('Two')),
            ]),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(ringedTexts(tester), isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    // The menu opens on the current value.
    expect(ringedTexts(tester), ['One']);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(ringedTexts(tester), ['Two']);
  });

  testWidgets('AppPopupMenuItem: ring on the focused row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PopupMenuButton<int>(
            itemBuilder: (_) => const [
              AppPopupMenuItem(value: 1, child: Text('One')),
              AppPopupMenuItem(value: 2, child: Text('Two')),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    final first = ringedTexts(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(first, hasLength(1));
    expect(ringedTexts(tester), hasLength(1));
    expect(ringedTexts(tester), isNot(first));
  });
}
