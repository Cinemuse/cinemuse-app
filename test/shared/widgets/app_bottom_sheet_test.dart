import 'package:cinemuse_app/shared/widgets/app_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openSheet(WidgetTester tester, {double? cornerWidth}) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => AppBottomSheet.show(
                context: context,
                cornerWidth: cornerWidth,
                child: const AppBottomSheet(
                  child: SizedBox(height: 200, child: Text('Sheet')),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a sheet is centred at the bottom', (tester) async {
    await openSheet(tester);

    final sheet = tester.getRect(find.byType(AppBottomSheet));
    expect(sheet.center.dx, 600);
    expect(sheet.bottom, 800);
  });

  // REV-333: the player's settings sit beside the video.
  testWidgets('with a corner width it rises in the bottom-right corner; a '
      'tap beside it closes it, a tap on it does not', (tester) async {
    await openSheet(tester, cornerWidth: 400);

    final sheet = tester.getRect(find.byType(AppBottomSheet));
    expect(sheet.width, 400);
    expect(sheet.right, 1200 - 16);
    expect(sheet.bottom, 800);

    await tester.tapAt(sheet.centerLeft + const Offset(8, 0));
    await tester.pumpAndSettle();
    expect(find.text('Sheet'), findsOneWidget);

    await tester.tapAt(const Offset(200, 700));
    await tester.pumpAndSettle();
    expect(find.text('Sheet'), findsNothing);
  });
}
