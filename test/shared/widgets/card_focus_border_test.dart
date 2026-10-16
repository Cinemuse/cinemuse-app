import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/card_focus_border.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';

void main() {
  testWidgets('CardFocusBorder renders inactive border when unfocused', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: CardFocusBorder()),
      ),
    );

    final containerFinder = find.byType(AnimatedContainer);
    expect(containerFinder, findsOneWidget);

    final container = tester.widget<AnimatedContainer>(containerFinder);
    final decoration = container.decoration as BoxDecoration;
    final border = decoration.border as Border;

    expect(border.top.color, equals(Colors.white.withValues(alpha: 0.1)));
    expect(border.top.width, equals(1.0));
    expect(decoration.boxShadow, isNull);
  });

  // REV-252: mouse and remote get the same pink border; only the remote
  // adds the ring, drawn around the picture (the card's DpadFocusable has
  // its own ring off).
  for (final isViaRemote in [true, false]) {
    testWidgets('CardFocusBorder: pink border, ring only via remote '
        '(${isViaRemote ? 'remote' : 'mouse'})', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: isViaRemote
                ? DpadFocusable(
                    focusNode: focusNode,
                    autofocus: true,
                    showFocusRing: false,
                    child: const CardFocusBorder(),
                  )
                : const CardFocusBorder(isHovered: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      final shownRings = tester
          .widgetList<FocusRing>(find.byType(FocusRing))
          .where((ring) => ring.isVisible);

      expect(border.top.color, equals(AppTheme.accent));
      expect(border.top.width, equals(2.0));
      expect(shownRings, hasLength(isViaRemote ? 1 : 0));
    });
  }
}
