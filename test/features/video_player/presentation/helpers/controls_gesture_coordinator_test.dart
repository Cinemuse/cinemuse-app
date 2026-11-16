import 'package:cinemuse_app/features/video_player/presentation/helpers/controls_gesture_coordinator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // With the Screen size at 2/3 on a TV, the player is 1440 wide in the
  // app's sizes but only 960 on the real screen: the side must come from
  // the app's sizes.
  test('a double tap skips by its side of the player at any screen size', () {
    final coordinator = ControlsGestureCoordinator();
    addTearDown(coordinator.dispose);
    final skips = <bool>[];

    // Right half of the player: 800 of 1440, which is 533 of 960 on screen.
    coordinator.onDoubleTapDown(
      TapDownDetails(
        globalPosition: const Offset(533, 300),
        localPosition: const Offset(800, 450),
      ),
    );
    coordinator.onDoubleTap(screenWidth: 1440, onSkip: skips.add);

    expect(skips, [true]);
  });
}
