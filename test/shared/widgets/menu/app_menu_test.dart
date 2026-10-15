import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/menu/app_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/menu_helpers.dart';

// REV-248: the right-click menu opened away from the pointer.
void main() {
  const screen = Size(1280, 800);

  final options = [
    for (final label in ['One', 'Two', 'Three', 'Four'])
      AppMenuOption(icon: Icons.star, label: label, onTap: () {}),
  ];

  // A wide window with a ⋮ button at [buttonAt]; a right-click anywhere
  // opens the menu at the pointer, the button opens it under itself.
  Future<void> pumpScreen(
    WidgetTester tester, {
    Offset buttonAt = const Offset(900, 100),
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onSecondaryTapDown: (d) => AppMenu.show(
                context: context,
                options: options,
                position: d.globalPosition,
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: buttonAt.dx,
                    top: buttonAt.dy,
                    child: Builder(
                      builder: (buttonContext) => IconButton(
                        tooltip: 'More',
                        icon: const Icon(Icons.more_vert),
                        onPressed: () => AppMenu.show(
                          context: buttonContext,
                          options: options,
                          anchorContext: buttonContext,
                        ),
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
  }

  // The left and the right half of the screen.
  for (final at in const [Offset(200, 150), Offset(1000, 300)]) {
    testWidgets('right-click at $at: the menu opens there', (tester) async {
      await pumpScreen(tester);
      await rightClickAt(tester, at);

      expectMenuAt(tester, at);
    });
  }

  testWidgets('right-click near the bottom-right corner: the menu stays on '
      'screen, next to the pointer', (tester) async {
    await pumpScreen(tester);
    const at = Offset(1270, 790);
    await rightClickAt(tester, at);

    final first = tester.getRect(menuItems.first);
    final last = tester.getRect(menuItems.last);
    expect(find.text('Four'), findsOneWidget);
    expect(first.top, greaterThanOrEqualTo(0));
    expect(last.right, lessThanOrEqualTo(at.dx + 1));
    expect(last.bottom, lessThanOrEqualTo(screen.height));
    expect(at.dx - last.right, lessThan(16));
  });

  for (final buttonAt in const [Offset(100, 100), Offset(900, 100)]) {
    testWidgets('the ⋮ button at $buttonAt opens the menu under it', (
      tester,
    ) async {
      await pumpScreen(tester, buttonAt: buttonAt);
      final button = tester.getRect(find.byType(IconButton));
      await tester.tap(find.byTooltip('More'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Under the button, lined up with one of its sides.
      final first = tester.getRect(menuItems.first);
      expect(first.top - button.bottom, inInclusiveRange(0, 16));
      expect(
        first.left == button.left || first.right == button.right,
        isTrue,
        reason: 'menu $first, button $button',
      );
    });
  }
}
