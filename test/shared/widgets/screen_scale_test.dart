import 'package:cinemuse_app/shared/widgets/screen_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// A Fire Stick: Android counts its 1920 x 1080 screen as 960 x 540.
  void useTvScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  Future<MediaQueryData> pumpScaled(WidgetTester tester, double scale) async {
    late MediaQueryData seen;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => ScreenScale(scale: scale, child: child!),
        home: Builder(
          builder: (context) {
            seen = MediaQuery.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    return seen;
  }

  testWidgets('at 2/3 the app lays itself out for a wider screen', (
    tester,
  ) async {
    useTvScreen(tester);
    final media = await pumpScaled(tester, 2 / 3);
    expect(media.size.width, closeTo(1440, 0.01));
    expect(media.size.height, closeTo(810, 0.01));
    // The real pixels per point: images are still loaded sharp.
    expect(media.devicePixelRatio, closeTo(4 / 3, 0.001));
  });

  testWidgets('above 100% it lays itself out for a narrower screen', (
    tester,
  ) async {
    useTvScreen(tester);
    final media = await pumpScaled(tester, 1.25);
    expect(media.size.width, closeTo(768, 0.01));
  });

  testWidgets('at 100% nothing changes', (tester) async {
    useTvScreen(tester);
    final media = await pumpScaled(tester, 1);
    expect(media.size, const Size(960, 540));
    expect(find.byType(FittedBox), findsNothing);
  });

  testWidgets('a tap lands on the item drawn under it', (tester) async {
    useTvScreen(tester);
    final taps = <String>[];
    Widget box(String name) => Expanded(
      child: GestureDetector(
        onTap: () => taps.add(name),
        child: ColoredBox(color: Colors.black, child: Text(name)),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => ScreenScale(scale: 2 / 3, child: child!),
        home: Row(children: [box('left'), box('right')]),
      ),
    );

    // On screen the right half starts at 480 whatever the size.
    expect(tester.getTopLeft(find.text('right')).dx, closeTo(480, 0.01));
    await tester.tapAt(const Offset(470, 270));
    await tester.tapAt(const Offset(490, 270));
    expect(taps, ['left', 'right']);
  });
}
