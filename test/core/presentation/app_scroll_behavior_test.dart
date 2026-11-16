import 'package:cinemuse_app/core/presentation/app_scroll_behavior.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A two-finger trackpad swipe: 8 movements `gapMs` apart (a busy
/// app delivers them further apart), then the fingers rest `holdMs` and lift.
typedef _Swipe = ({String name, int gapMs, int holdMs, bool shouldGlide});

void main() {
  // REV-254: on Windows the trackpad samples arrive late while the app is
  // drawing; the swipe must still glide after the fingers lift.
  group('trackpad swipe glide', () {
    const List<_Swipe> cases = [
      (name: 'app idle', gapMs: 16, holdMs: 0, shouldGlide: true),
      (name: 'app busy drawing', gapMs: 60, holdMs: 0, shouldGlide: true),
      (
        name: 'fingers rest before lifting',
        gapMs: 16,
        holdMs: 150,
        shouldGlide: false,
      ),
    ];

    for (final c in cases) {
      testWidgets(c.name, (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            scrollBehavior: const AppScrollBehavior(),
            home: ListView.builder(
              controller: controller,
              itemExtent: 100,
              itemCount: 1000,
              itemBuilder: (_, i) => Text('Row $i'),
            ),
          ),
        );

        final center = tester.getCenter(find.byType(ListView));
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.trackpad,
        );
        var time = Duration.zero;
        await gesture.panZoomStart(center, timeStamp: time);
        for (var i = 1; i <= 8; i++) {
          time += Duration(milliseconds: c.gapMs);
          await tester.pump(Duration(milliseconds: c.gapMs));
          await gesture.panZoomUpdate(
            center,
            pan: Offset(0, -40.0 * i),
            timeStamp: time,
          );
        }
        if (c.holdMs > 0) {
          time += Duration(milliseconds: c.holdMs);
          await tester.pump(Duration(milliseconds: c.holdMs));
        }
        await gesture.panZoomEnd(timeStamp: time);
        await tester.pump();
        final atLift = controller.offset;

        await tester.pump(const Duration(milliseconds: 300));
        final glided = controller.offset - atLift;
        expect(glided > 20, c.shouldGlide, reason: 'glided $glided px');
        await tester.pumpAndSettle();
      });
    }
  });
}
