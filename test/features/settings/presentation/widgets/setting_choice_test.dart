import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_choice.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/app_font.dart';
import '../../../../helpers/focus_helpers.dart';

void main() {
  setUpAll(loadAppFont);

  late String fruit;
  late int number;

  const wide = Size(1280, 900);
  const phone = Size(360, 800);

  /// Three rows: a short list, a long one (it scrolls in its box), and one
  /// more below to see where the rows end up.
  Future<void> pumpRows(
    WidgetTester tester, {
    Size size = wide,
    int startNumber = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    FocusRing.debugWatchKeys();
    fruit = 'Pear';
    number = startNumber;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ListView(
              children: [
                SettingsChoiceTile<String>(
                  label: 'Fruit',
                  description: 'The fruit on the table.',
                  icon: Icons.star,
                  value: fruit,
                  choices: const [
                    SettingsChoice('Apple', 'Apple'),
                    SettingsChoice('Pear', 'Pear'),
                    SettingsChoice('Plum', 'Plum'),
                  ],
                  onChanged: (v) => setState(() => fruit = v),
                ),
                SettingsChoiceTile<int>(
                  label: 'Number',
                  description: 'A number from one to forty.',
                  icon: Icons.numbers,
                  value: number,
                  choices: [
                    for (var i = 1; i <= 40; i++) SettingsChoice(i, 'N$i'),
                  ],
                  onChanged: (v) => setState(() => number = v),
                ),
                SettingsChoiceTile<String>(
                  label: 'Last row',
                  icon: Icons.flag,
                  value: 'a',
                  choices: const [SettingsChoice('a', 'Alpha')],
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double top(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  testWidgets('a tap opens the list right under the row; a pick saves it '
      'and closes the list', (tester) async {
    await pumpRows(tester);
    expect(find.text('Apple'), findsNothing);

    await tester.tap(find.text('Fruit'));
    await tester.pumpAndSettle();
    expect(top(tester, 'Apple'), greaterThan(top(tester, 'Fruit')));
    expect(top(tester, 'Plum'), lessThan(top(tester, 'Number')));

    await tester.tap(find.text('Plum'));
    await tester.pumpAndSettle();
    expect(fruit, 'Plum');
    expect(find.text('Apple'), findsNothing);
    expect(find.text('Plum'), findsOneWidget); // The row's current choice.
  });

  testWidgets('a tap on the open row closes it, nothing changed', (
    tester,
  ) async {
    await pumpRows(tester);
    await tester.tap(find.text('Fruit'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fruit'));
    await tester.pumpAndSettle();
    expect(find.text('Apple'), findsNothing);
    expect(fruit, 'Pear');
  });

  testWidgets('opening another list closes the first', (tester) async {
    await pumpRows(tester);
    await tester.tap(find.text('Fruit'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Last row'));
    await tester.pumpAndSettle();
    expect(find.text('Apple'), findsNothing);
    expect(find.text('Alpha'), findsNWidgets(2)); // The row and its list.
  });

  testWidgets('a long list scrolls in its own box: the rows below stay '
      'close', (tester) async {
    await pumpRows(tester);
    await tester.tap(find.text('Number'));
    await tester.pumpAndSettle();

    expect(top(tester, 'Last row') - top(tester, 'Number'), lessThan(400));
    expect(find.text('N40', skipOffstage: false), findsOneWidget);
  });

  testWidgets('keys: Enter opens the list on the current choice, ↓ and '
      'Enter pick the next one, and the focus goes back to the row', (
    tester,
  ) async {
    await pumpRows(tester);
    await tabTo(tester, find.text('Fruit'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    // The list's Pear, not the row's.
    expect(isFocused(find.text('Pear').last), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(isFocused(find.text('Plum')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(fruit, 'Plum');
    expect(find.text('Apple'), findsNothing);
    expect(isFocused(find.text('Fruit')), isTrue);
  });

  for (final (name, pressKey) in [
    ('Esc', () => simulateKeyDownEvent(LogicalKeyboardKey.escape)),
    (
      "the remote's Back",
      // Flutter's test keys have no Android scan code for it: sent as the
      // web names it, the app sees the same Back key.
      () => simulateKeyDownEvent(
        LogicalKeyboardKey.goBack,
        physicalKey: PhysicalKeyboardKey.browserBack,
        platform: 'web',
      ),
    ),
  ]) {
    testWidgets('$name closes the list, nothing changed, and the focus goes '
        'back to the row', (tester) async {
      await pumpRows(tester);
      await tabTo(tester, find.text('Fruit'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      await pressKey();
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsNothing);
      expect(fruit, 'Pear');
      expect(isFocused(find.text('Fruit')), isTrue);
    });
  }

  testWidgets('keys: in a long list the current choice is shown', (
    tester,
  ) async {
    await pumpRows(tester, startNumber: 30);

    await tabTo(tester, find.text('Number'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(isFocused(find.text('N30').last), isTrue);
    expect(find.text('N30').last.hitTestable(), findsOneWidget);
  });

  testWidgets('Tab stops on the whole row and shows its ring', (tester) async {
    await pumpRows(tester);
    await tabTo(tester, find.text('Fruit'));
    await tester.pumpAndSettle();

    final rings = tester.widgetList<FocusRing>(
      find.ancestor(of: find.text('Fruit'), matching: find.byType(FocusRing)),
    );
    expect(rings.any((r) => r.isVisible), isTrue);
    // The row's ring holds the current choice too: one ring for the row.
    final ringed = find.ancestor(
      of: find.text('Fruit'),
      matching: find.byWidgetPredicate((w) => w is FocusRing && w.isVisible),
    );
    expect(
      find.descendant(of: ringed, matching: find.text('Pear')),
      findsOneWidget,
    );
  });

  testWidgets('on a phone the current choice is under the label and the '
      'description shows only in the open list', (tester) async {
    await pumpRows(tester, size: phone);
    expect(find.text('The fruit on the table.'), findsNothing);
    expect(top(tester, 'Pear'), greaterThan(top(tester, 'Fruit')));
    // The label has the row's width: one line.
    expect(tester.getSize(find.text('Fruit')).height, lessThan(30));

    await tester.tap(find.text('Fruit'));
    await tester.pumpAndSettle();
    expect(find.text('The fruit on the table.'), findsOneWidget);
  });

  testWidgets('wider screens show the description and the current choice '
      'on the row', (tester) async {
    await pumpRows(tester);
    expect(find.text('The fruit on the table.'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Pear')).dx,
      greaterThan(tester.getTopLeft(find.text('The fruit on the table.')).dx),
    );
  });
}
