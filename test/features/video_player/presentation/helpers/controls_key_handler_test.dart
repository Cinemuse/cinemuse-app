import 'package:cinemuse_app/features/video_player/presentation/helpers/controls_key_handler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ControlsKeyHandler Esc with hidden controls (REV-158)', () {
    late List<String> calls;

    KeyEventResult pressEsc({required bool isFullscreen}) {
      return ControlsKeyHandler().handleKeyEvent(
        event: const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.escape,
          logicalKey: LogicalKeyboardKey.escape,
          timeStamp: Duration.zero,
        ),
        isLive: false,
        isOverlayOpen: false,
        isVisible: false,
        isFullscreen: isFullscreen,
        isFullOrStandalone: true,
        numberBuffer: '',
        onTogglePlayPause: () => calls.add('playPause'),
        onSkip: (forward, {showControls = true}) => calls.add('skip'),
        onToggleMute: () => calls.add('mute'),
        onToggleFullscreen: () => calls.add('fullscreen'),
        onBack: () => calls.add('back'),
        onShowControls: () => calls.add('show'),
        onHideControls: () => calls.add('hide'),
        onFocusPlayPause: () => calls.add('focus'),
        onHover: () => calls.add('hover'),
        onNumberInput: (_) => calls.add('number'),
        onConfirmNumber: () => calls.add('confirm'),
        onZapNextChannel: () => calls.add('next'),
        onZapPreviousChannel: () => calls.add('previous'),
        onOpenChannelOverlay: () => calls.add('overlay'),
      );
    }

    setUp(() => calls = []);

    test('in fullscreen only leaves fullscreen', () {
      expect(pressEsc(isFullscreen: true), KeyEventResult.handled);
      expect(calls, ['fullscreen']);
    });

    test('in a window goes back', () {
      expect(pressEsc(isFullscreen: false), KeyEventResult.handled);
      expect(calls, ['back']);
    });
  });
}
