import 'package:cinemuse_app/features/video_player/presentation/widgets/vod_seekbar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlayer extends Mock implements Player {}

String _format(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

// REV-288: the time shown while hovering is where a click jumps to, also
// near both ends of the bar.
void main() {
  for (final (name, fraction) in [('start', 0.1), ('end', 0.9)]) {
    testWidgets('hover time = click time near the $name', (tester) async {
      double? clicked;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: VodSeekbar(
                  player: _MockPlayer(),
                  position: Duration.zero,
                  duration: const Duration(minutes: 50),
                  onChangeStart: (_) {},
                  onChanged: (_) {},
                  onChangeEnd: (v) => clicked = v,
                ),
              ),
            ),
          ),
        ),
      );
      final bar = tester.getRect(find.byType(Slider));
      final point = Offset(bar.left + bar.width * fraction, bar.center.dy);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(point);
      await tester.pump();
      final hovered = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .toList();
      await mouse.down(point);
      await tester.pump();
      await mouse.up();
      await tester.pump();

      expect(clicked, isNotNull);
      expect(hovered, contains(_format(clicked!.toInt())));
    });
  }
}
