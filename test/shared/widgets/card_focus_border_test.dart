import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/card_focus_border.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

void main() {
  testWidgets('CardFocusBorder renders inactive border when unfocused', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: CardFocusBorder(),
        ),
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

  testWidgets('CardFocusBorder renders high-contrast focus border and glow when focused via DpadFocusable', (tester) async {
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: DpadFocusable(
            focusNode: focusNode,
            autofocus: true,
            child: const CardFocusBorder(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(focusNode.hasFocus, isTrue);

    final containerFinder = find.byType(AnimatedContainer);
    expect(containerFinder, findsOneWidget);

    final container = tester.widget<AnimatedContainer>(containerFinder);
    final decoration = container.decoration as BoxDecoration;
    final border = decoration.border as Border;

    expect(border.top.color, equals(AppTheme.accent));
    expect(border.top.width, equals(2.0));
    expect(decoration.boxShadow, isNull);
  });

  testWidgets('CardFocusBorder renders hover border when hovered', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: CardFocusBorder(isHovered: true),
        ),
      ),
    );

    final containerFinder = find.byType(AnimatedContainer);
    expect(containerFinder, findsOneWidget);

    final container = tester.widget<AnimatedContainer>(containerFinder);
    final decoration = container.decoration as BoxDecoration;
    final border = decoration.border as Border;

    expect(border.top.color, equals(AppTheme.accent.withValues(alpha: 0.5)));
    expect(border.top.width, equals(1.5));
    expect(decoration.boxShadow, isNull);
  });
}
