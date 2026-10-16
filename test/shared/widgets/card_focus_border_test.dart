import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/card_focus_border.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';

void main() {
  // REV-252: no frame on hover or focus, only the subtle outline; the
  // remote adds the ring around the picture (the card's DpadFocusable has
  // its own ring off).
  for (final isViaRemote in [true, false]) {
    testWidgets('CardFocusBorder: no frame, ring only via remote '
        '(${isViaRemote ? 'remote' : 'mouse'})', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: DpadFocusable(
                focusNode: focusNode,
                autofocus: isViaRemote,
                showFocusRing: false,
                onTap: () {},
                child: const SizedBox(
                  width: 100,
                  height: 150,
                  child: CardFocusBorder(),
                ),
              ),
            ),
          ),
        ),
      );
      if (!isViaRemote) {
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        addTearDown(mouse.removePointer);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(find.byType(CardFocusBorder)));
      }
      await tester.pumpAndSettle();

      final scope = tester.widget<DpadFocusScope>(find.byType(DpadFocusScope));
      final outline = tester.widget<Container>(
        find.descendant(
          of: find.byType(CardFocusBorder),
          matching: find.byType(Container),
        ),
      );
      final border = (outline.decoration as BoxDecoration).border as Border;
      final shownRings = tester
          .widgetList<FocusRing>(find.byType(FocusRing))
          .where((ring) => ring.isVisible);

      expect(isViaRemote ? scope.isFocused : scope.isHovered, isTrue);
      expect(border.top.color, Colors.white.withValues(alpha: 0.1));
      expect(border.top.width, 1.0);
      expect(shownRings, hasLength(isViaRemote ? 1 : 0));
    });
  }
}
