import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/settings/selectable_option_tile.dart';

import '../../../../../helpers/focus_helpers.dart';

void main() {
  final picked = <String>[];

  Widget tile(String label, {bool isSelected = false}) => SelectableOptionTile(
    isSelected: isSelected,
    onTap: () => picked.add(label),
    child: Text(label),
  );

  Future<void> pumpList(WidgetTester tester) async {
    picked.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [tile('1080p', isSelected: true), tile('720p')],
          ),
        ),
      ),
    );
  }

  testWidgets('only the current choice shows the check mark', (tester) async {
    await pumpList(tester);

    final check = find.byIcon(Icons.check_circle_rounded);
    expect(check, findsOneWidget);
    final selectedRow = find.ancestor(
      of: find.text('1080p'),
      matching: find.byType(SelectableOptionTile),
    );
    expect(find.descendant(of: selectedRow, matching: check), findsOneWidget);
  });

  testWidgets('a choice on its way spins instead of the check mark', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectableOptionTile(
            isSelected: false,
            isLoading: true,
            onTap: () {},
            child: const Text('English'),
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
  });

  testWidgets('a row under the mouse: the brand purple', (tester) async {
    await pumpList(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('720p')));
    await tester.pumpAndSettle();

    final row = tester.widget<Container>(
      find.descendant(
        of: find.ancestor(
          of: find.text('720p'),
          matching: find.byType(SelectableOptionTile),
        ),
        matching: find.byType(Container),
      ),
    );
    final decoration = row.decoration! as BoxDecoration;
    expect(decoration.color, AppTheme.accentHoverBg);
    expect((decoration.border! as Border).top.color, AppTheme.border);
  });

  testWidgets('a row picks with a tap and with the keys', (tester) async {
    await pumpList(tester);

    await tester.tap(find.text('720p'));
    await tabTo(tester, find.text('1080p'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    expect(picked, ['720p', '1080p']);
  });
}
