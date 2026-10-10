import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/shared/widgets/carousels/generic_carousel_row.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

void main() {
  testWidgets('Pressing arrowLeft on the first card keeps focus there', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: GenericCarouselRow(
              height: 200,
              itemCount: 5,
              itemBuilder: (context, index) {
                return SizedBox(
                  width: 100,
                  height: 150,
                  child: DpadFocusable(
                    onTap: _noop,
                    child: Text('Card $index'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Card 0'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    final card0Focus = tester.widget<Focus>(
      find
          .ancestor(of: find.text('Card 0'), matching: find.byType(Focus))
          .first,
    );
    expect(card0Focus.focusNode?.hasFocus, isTrue);
  });

  testWidgets(
    'Pressing arrowRight on last item stays on that item and does not escape',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  GenericCarouselRow(
                    title: 'Row 1',
                    height: 200,
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      return SizedBox(
                        width: 100,
                        height: 150,
                        child: DpadFocusable(
                          onTap: _noop,
                          child: Text('Row1 Card $index'),
                        ),
                      );
                    },
                  ),
                  GenericCarouselRow(
                    title: 'Row 2',
                    height: 200,
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      return SizedBox(
                        width: 100,
                        height: 150,
                        child: DpadFocusable(
                          onTap: _noop,
                          child: Text('Row2 Card $index'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Focus the last card in Row 1 (Card 2)
      await tester.tap(find.text('Row1 Card 2'));
      await tester.pumpAndSettle();

      // Press and hold (repeat) arrowRight on the last card
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      for (int i = 0; i < 5; i++) {
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      // Verify focus is still within Row 1 (has not jumped to Row 2)
      final row2Card0 = find.text('Row2 Card 0');
      final row2Card0Focus = tester.widget<Focus>(
        find.ancestor(of: row2Card0, matching: find.byType(Focus)).first,
      );
      expect(row2Card0Focus.focusNode?.hasFocus ?? false, isFalse);

      // Focus Card 0 in Row 2
      await tester.tap(find.text('Row2 Card 0'));
      await tester.pumpAndSettle();

      // Press and hold (repeat) arrowLeft on Card 0
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      for (int i = 0; i < 5; i++) {
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      // Verify focus has NOT escaped to Row 1
      final row1Card2Focus = tester.widget<Focus>(
        find
            .ancestor(
              of: find.text('Row1 Card 2'),
              matching: find.byType(Focus),
            )
            .first,
      );
      expect(row1Card2Focus.focusNode?.hasFocus ?? false, isFalse);
    },
  );

  testWidgets('Row Memory preserves the last focused card in each row', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                GenericCarouselRow(
                  title: 'Row 1',
                  height: 200,
                  itemCount: 4,
                  itemBuilder: (context, index) {
                    return SizedBox(
                      width: 100,
                      height: 150,
                      child: DpadFocusable(
                        onTap: _noop,
                        child: Text('Row1 Card $index'),
                      ),
                    );
                  },
                ),
                GenericCarouselRow(
                  title: 'Row 2',
                  height: 200,
                  itemCount: 4,
                  itemBuilder: (context, index) {
                    return SizedBox(
                      width: 100,
                      height: 150,
                      child: DpadFocusable(
                        onTap: _noop,
                        child: Text('Row2 Card $index'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Focus Card 0 in Row 1
    await tester.tap(find.text('Row1 Card 0'));
    await tester.pumpAndSettle();

    // Navigate right to Card 2 in Row 1
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    // Navigate Down to Row 2 for the FIRST time: must start from the first card on the left (Card 0)!
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    final row2Card0 = find.text('Row2 Card 0');
    final row2Card0Focus = tester.widget<Focus>(
      find.ancestor(of: row2Card0, matching: find.byType(Focus)).first,
    );
    expect(row2Card0Focus.focusNode?.hasFocus, isTrue);

    // Move across to Card 3 in Row 2
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    // Navigate Up back to Row 1: Row Memory should restore Card 2!
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    // Verify Row 1 restored focus to Row1 Card 2!
    final row1Card2 = find.text('Row1 Card 2');
    final row1Card2Focus = tester.widget<Focus>(
      find.ancestor(of: row1Card2, matching: find.byType(Focus)).first,
    );
    expect(row1Card2Focus.focusNode?.hasFocus, isTrue);

    // Navigate Down again back to Row 2: should restore Row2 Card 3!
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final row2Card3 = find.text('Row2 Card 3');
    final row2Card3Focus = tester.widget<Focus>(
      find.ancestor(of: row2Card3, matching: find.byType(Focus)).first,
    );
    expect(row2Card3Focus.focusNode?.hasFocus, isTrue);
  });

  testWidgets(
    'Row with non-focusable headers (like sport schedule) does not escape between rows',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  GenericCarouselRow(
                    title: 'Row Above',
                    height: 200,
                    itemCount: 3,
                    itemBuilder: (context, index) => SizedBox(
                      width: 100,
                      height: 150,
                      child: DpadFocusable(
                        onTap: _noop,
                        child: Text('Above $index'),
                      ),
                    ),
                  ),
                  GenericCarouselRow(
                    title: 'Sport Schedule',
                    height: 200,
                    // index 0: Header (Today, not focusable)
                    // index 1: Event 1 (focusable)
                    // index 2: Header (Tomorrow, not focusable)
                    // index 3: Event 2 (focusable)
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return const SizedBox(width: 72, child: Text('TODAY'));
                      }
                      if (index == 1) {
                        return const SizedBox(
                          width: 150,
                          child: DpadFocusable(
                            onTap: _noop,
                            child: Text('Event 1'),
                          ),
                        );
                      }
                      if (index == 2) {
                        return const SizedBox(
                          width: 72,
                          child: Text('TOMORROW'),
                        );
                      }
                      return const SizedBox(
                        width: 150,
                        child: DpadFocusable(
                          onTap: _noop,
                          child: Text('Event 2'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Focus Event 1 (first focusable card in sport schedule)
      await tester.tap(find.text('Event 1'));
      await tester.pumpAndSettle();

      // Press arrowLeft on Event 1 (index 1, where index 0 is non-focusable): should NOT escape to Row Above!
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      final above0 = find.text('Above 0');
      final above0Focus = tester.widget<Focus>(
        find.ancestor(of: above0, matching: find.byType(Focus)).first,
      );
      expect(above0Focus.focusNode?.hasFocus ?? false, isFalse);

      // Press arrowRight on Event 1: jumps across non-focusable TOMORROW header to Event 2!
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      final event2 = find.text('Event 2');
      final event2Focus = tester.widget<Focus>(
        find.ancestor(of: event2, matching: find.byType(Focus)).first,
      );
      expect(event2Focus.focusNode?.hasFocus, isTrue);

      // Press arrowRight on Event 2 (last focusable card): should clamp and NOT escape!
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(event2Focus.focusNode?.hasFocus, isTrue);
    },
  );

  for (final theme in [CarouselTheme.homeRow, CarouselTheme.profileRow]) {
    testWidgets(
      'Row title opens the full list on click and with Enter (${theme.name})',
      (tester) async {
        var headerTaps = 0;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: GenericCarouselRow(
                  title: 'Movies',
                  theme: theme,
                  height: 200,
                  itemCount: 2,
                  onHeaderTap: () => headerTaps++,
                  itemBuilder: (context, index) => SizedBox(
                    width: 100,
                    height: 150,
                    child: DpadFocusable(
                      onTap: _noop,
                      child: Text('Movie $index'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The old Big Picture "See All" card is gone: the title is the link.
        expect(find.text('See All'), findsNothing);

        await tester.tap(find.text('Movies'));
        await tester.pumpAndSettle();
        expect(headerTaps, 1);

        // Remote / keyboard: move up from the first card to the title, Enter.
        await tester.tap(find.text('Movie 0'));
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(headerTaps, 2);
      },
    );
  }

  testWidgets(
    'Navigating down and up between multiple rows in SingleChildScrollView changes row on each single press',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    for (int r = 0; r < 5; r++)
                      GenericCarouselRow(
                        title: 'Row $r',
                        height: 250,
                        itemCount: 4,
                        itemBuilder: (context, index) => SizedBox(
                          width: 150,
                          height: 200,
                          child: DpadFocusable(
                            onTap: _noop,
                            child: Text('R${r}C$index'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      bool isCardFocused(String text) {
        final finder = find.text(text);
        final focusWidget = tester.widget<Focus>(
          find.ancestor(of: finder, matching: find.byType(Focus)).first,
        );
        return focusWidget.focusNode?.hasFocus ?? false;
      }

      // Focus R0C0
      await tester.tap(find.text('R0C0'));
      await tester.pumpAndSettle();
      expect(isCardFocused('R0C0'), isTrue);

      // Press arrowDown: should move to Row 1 on 1st press!
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(isCardFocused('R1C0'), isTrue);

      // Press arrowDown: should move to Row 2 on 1st press!
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(isCardFocused('R2C0'), isTrue);

      // Press arrowDown: should move to Row 3 on 1st press!
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(isCardFocused('R3C0'), isTrue);

      // Press arrowDown: should move to Row 4 on 1st press!
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(isCardFocused('R4C0'), isTrue);

      // Press arrowUp: should move to Row 3 on 1st press!
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(isCardFocused('R3C0'), isTrue);

      // Press arrowUp: should move to Row 2 on 1st press!
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(isCardFocused('R2C0'), isTrue);

      // Press arrowUp: should move to Row 1 on 1st press!
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(isCardFocused('R1C0'), isTrue);

      // Press arrowUp: should move to Row 0 on 1st press!
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(isCardFocused('R0C0'), isTrue);
    },
  );
}

// Real cards always have an action (open details); without one a
// DpadFocusable ignores taps (REV-39), so tapping would not focus it.
void _noop() {}
