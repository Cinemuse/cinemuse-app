import 'package:cinemuse_app/shared/widgets/bento_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('fixed-height BentoBox with an icon-only header fits its child', (
    tester,
  ) async {
    const childKey = Key('child');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              child: BentoBox(
                title: '',
                icon: Icons.tv,
                height: 200,
                child: SizedBox.expand(key: childKey),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final childBottom = tester.getBottomLeft(find.byKey(childKey)).dy;
    final boxBottom = tester.getBottomLeft(find.byType(BentoBox)).dy;
    expect(tester.getSize(find.byType(BentoBox)).height, 200);
    expect(childBottom, lessThanOrEqualTo(boxBottom));
  });
}
