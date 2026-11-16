import 'package:cinemuse_app/features/video_player/presentation/helpers/controls_key_handler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> calls;

  KeyEventResult press(
    LogicalKeyboardKey key, {
    bool isLive = false,
    bool isFullscreen = false,
    bool isVisible = false,
  }) {
    return ControlsKeyHandler().handleKeyEvent(
      event: KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.escape,
        logicalKey: key,
        timeStamp: Duration.zero,
      ),
      isLive: isLive,
      isOverlayOpen: false,
      isVisible: isVisible,
      isFullscreen: isFullscreen,
      numberBuffer: '',
      onTogglePlayPause: () => calls.add('playPause'),
      onSkip: (forward, {showControls = true}) =>
          calls.add(forward ? 'skip forward' : 'skip back'),
      onToggleMute: () => calls.add('mute'),
      onToggleFullscreen: () => calls.add('fullscreen'),
      onToggleAppFullScreen: () => calls.add('app full screen'),
      onBack: () => calls.add('back'),
      onShowControls: () => calls.add('show'),
      onHideControls: () => calls.add('hide'),
      onFocusPlayPause: () => calls.add('focus'),
      onHover: () => calls.add('hover'),
      onNumberInput: (_) => calls.add('number'),
      onConfirmNumber: () => calls.add('confirm'),
      onZapNextChannel: () => calls.add('next'),
      onZapPreviousChannel: () => calls.add('previous'),
    );
  }

  setUp(() => calls = []);

  group('ControlsKeyHandler Esc with hidden controls (REV-158)', () {
    test('in fullscreen only leaves fullscreen', () {
      expect(
        press(LogicalKeyboardKey.escape, isFullscreen: true),
        KeyEventResult.handled,
      );
      expect(calls, ['fullscreen']);
    });

    test('in a window goes back', () {
      expect(press(LogicalKeyboardKey.escape), KeyEventResult.handled);
      expect(calls, ['back']);
    });
  });

  for (final isVisible in [false, true]) {
    test('F is the player\'s full screen, F11 the whole app\'s '
        '(controls ${isVisible ? 'shown' : 'hidden'})', () {
      press(LogicalKeyboardKey.keyF, isVisible: isVisible);
      press(LogicalKeyboardKey.f11, isVisible: isVisible);
      expect(calls.where((c) => c != 'hover'), [
        'fullscreen',
        'app full screen',
      ]);
    });
  }

  test('live TV with hidden controls: Left and Right skip as on a film, '
      'Up and Down change channel', () {
    press(LogicalKeyboardKey.arrowLeft, isLive: true);
    press(LogicalKeyboardKey.arrowRight, isLive: true);
    press(LogicalKeyboardKey.arrowUp, isLive: true);
    press(LogicalKeyboardKey.arrowDown, isLive: true);
    expect(calls, ['skip back', 'skip forward', 'previous', 'next']);
  });
}
