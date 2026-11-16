import 'package:cinemuse_app/features/explore/presentation/widgets/filter_range_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a drag reports one value, when it ends', (tester) async {
    final reported = <RangeValues>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: FilterRangeSlider(
              min: 0,
              max: 100,
              values: const RangeValues(0, 100),
              onChanged: reported.add,
              label: 'Rating',
              formatValue: (v) => '${v.start.round()} - ${v.end.round()}',
              icon: Icons.star,
            ),
          ),
        ),
      ),
    );

    final slider = tester.getRect(find.byType(RangeSlider));
    final gesture = await tester.startGesture(
      slider.centerRight.translate(-30, 0),
    );
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(-10, 0));
      await tester.pump();
    }
    expect(reported, isEmpty);
    expect(find.text('0 - 100'), findsNothing); // the label follows the drag

    await gesture.up();
    await tester.pump();
    expect(reported, hasLength(1));
  });
}
