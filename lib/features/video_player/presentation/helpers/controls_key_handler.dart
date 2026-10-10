import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Encapsulates keyboard and D-Pad navigation event parsing for [CustomVideoControls].
class ControlsKeyHandler {
  DateTime? _lastHiddenSkipTime;

  KeyEventResult handleKeyEvent({
    required KeyEvent event,
    required bool isLive,
    required bool isOverlayOpen,
    required bool isVisible,
    required bool isFullscreen,
    required bool isFullOrStandalone,
    required String numberBuffer,
    required void Function() onTogglePlayPause,
    required void Function(bool forward, {bool showControls}) onSkip,
    required void Function() onToggleMute,
    required void Function() onToggleFullscreen,
    required void Function() onBack,
    required void Function() onShowControls,
    required void Function() onHideControls,
    required void Function() onFocusPlayPause,
    required void Function() onHover,
    required void Function(String digit) onNumberInput,
    required void Function() onConfirmNumber,
    required void Function() onZapNextChannel,
    required void Function() onZapPreviousChannel,
    required void Function() onOpenChannelOverlay,
  }) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    // Channel drawer overlay handling: overlay navigation is completely self-contained.
    if (isOverlayOpen) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    // Direct channel number input (0-9)
    if (isLive) {
      final keyLabel = key.keyLabel;
      if (keyLabel.length == 1 && int.tryParse(keyLabel) != null) {
        if (event is KeyDownEvent) {
          onNumberInput(keyLabel);
        }
        onHover();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        if (numberBuffer.isNotEmpty) {
          if (event is KeyDownEvent) {
            onConfirmNumber();
          }
          return KeyEventResult.handled;
        }
      }
    }

    // Media keys (hardware remotes / keyboards)
    final mediaResult = _handleMediaKeys(event, key, onTogglePlayPause, onSkip);
    if (mediaResult != KeyEventResult.ignored) return mediaResult;

    if (!isVisible) {
      return _handleHiddenControlsKeys(
        event: event,
        key: key,
        isLive: isLive,
        isFullOrStandalone: isFullOrStandalone,
        onTogglePlayPause: onTogglePlayPause,
        onSkip: onSkip,
        onShowControls: onShowControls,
        onFocusPlayPause: onFocusPlayPause,
        onZapPreviousChannel: onZapPreviousChannel,
        onZapNextChannel: onZapNextChannel,
        onOpenChannelOverlay: onOpenChannelOverlay,
        onBack: onBack,
        onToggleFullscreen: onToggleFullscreen,
        onToggleMute: onToggleMute,
      );
    }

    return _handleVisibleControlsKeys(
      event: event,
      key: key,
      isFullscreen: isFullscreen,
      onTogglePlayPause: onTogglePlayPause,
      onToggleFullscreen: onToggleFullscreen,
      onHideControls: onHideControls,
      onToggleMute: onToggleMute,
      onBack: onBack,
      onHover: onHover,
    );
  }

  KeyEventResult _handleMediaKeys(
    KeyEvent event,
    LogicalKeyboardKey key,
    void Function() onTogglePlayPause,
    void Function(bool forward, {bool showControls}) onSkip,
  ) {
    if (key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.mediaPlay ||
        key == LogicalKeyboardKey.mediaPause) {
      if (event is KeyDownEvent) onTogglePlayPause();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaFastForward) {
      onSkip(true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaRewind) {
      onSkip(false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleHiddenControlsKeys({
    required KeyEvent event,
    required LogicalKeyboardKey key,
    required bool isLive,
    required bool isFullOrStandalone,
    required void Function() onTogglePlayPause,
    required void Function(bool forward, {bool showControls}) onSkip,
    required void Function() onShowControls,
    required void Function() onFocusPlayPause,
    required void Function() onZapPreviousChannel,
    required void Function() onZapNextChannel,
    required void Function() onOpenChannelOverlay,
    required void Function() onBack,
    required void Function() onToggleFullscreen,
    required void Function() onToggleMute,
  }) {
    if (key == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) onTogglePlayPause();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA) {
      if (event is KeyDownEvent) {
        onShowControls();
        onFocusPlayPause();
      }
      return KeyEventResult.handled;
    }

    // Up / Down / Channel Up / Channel Down / Page Up / Page Down:
    // Live TV: Zaps channels!
    // VOD: Unused!
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.channelUp ||
        key == LogicalKeyboardKey.channelDown ||
        key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.pageDown) {
      if (isLive) {
        if (event is KeyDownEvent) {
          final isUp =
              key == LogicalKeyboardKey.arrowUp ||
              key == LogicalKeyboardKey.channelUp ||
              key == LogicalKeyboardKey.pageUp;
          if (isUp) {
            onZapPreviousChannel();
          } else {
            onZapNextChannel();
          }
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (isLive) {
        if (event is KeyDownEvent) {
          if (isFullOrStandalone) {
            onOpenChannelOverlay();
          }
        }
        return KeyEventResult.handled;
      }
      final now = DateTime.now();
      if (event is KeyRepeatEvent) {
        if (_lastHiddenSkipTime != null &&
            now.difference(_lastHiddenSkipTime!).inMilliseconds < 110) {
          return KeyEventResult.handled;
        }
      }
      _lastHiddenSkipTime = now;
      onSkip(false, showControls: false);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      if (isLive) {
        return KeyEventResult.handled;
      }
      final now = DateTime.now();
      if (event is KeyRepeatEvent) {
        if (_lastHiddenSkipTime != null &&
            now.difference(_lastHiddenSkipTime!).inMilliseconds < 110) {
          return KeyEventResult.handled;
        }
      }
      _lastHiddenSkipTime = now;
      onSkip(true, showControls: false);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.goBack) {
      if (event is KeyDownEvent) onBack();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF || key == LogicalKeyboardKey.f11) {
      if (event is KeyDownEvent) onToggleFullscreen();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyM) {
      if (event is KeyDownEvent) onToggleMute();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleVisibleControlsKeys({
    required KeyEvent event,
    required LogicalKeyboardKey key,
    required bool isFullscreen,
    required void Function() onTogglePlayPause,
    required void Function() onToggleFullscreen,
    required void Function() onHideControls,
    required void Function() onToggleMute,
    required void Function() onBack,
    required void Function() onHover,
  }) {
    onHover();

    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.goBack) {
      if (event is KeyDownEvent) {
        if (isFullscreen) {
          onToggleFullscreen();
        } else {
          onHideControls();
        }
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) onTogglePlayPause();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyM) {
      if (event is KeyDownEvent) onToggleMute();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF || key == LogicalKeyboardKey.f11) {
      if (event is KeyDownEvent) onToggleFullscreen();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyQ) {
      if (event is KeyDownEvent) onBack();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }
}
