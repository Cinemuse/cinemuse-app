import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';

/// Encapsulates touch/mouse vertical drag adjustments (brightness and volume)
/// and double-tap seeking calculations for the video player controls.
class ControlsGestureCoordinator {
  DragType _currentDragType = DragType.none;
  double _brightnessLevel = 1.0;
  double _dragIndicatorValue = 0.0;
  Offset? _doubleTapPosition;
  Timer? _hideIndicatorTimer;

  DragType get currentDragType => _currentDragType;
  double get brightnessLevel => _brightnessLevel;
  double get dragIndicatorValue => _dragIndicatorValue;

  void dispose() {
    _hideIndicatorTimer?.cancel();
    _hideIndicatorTimer = null;
  }

  void onVerticalDragStart({
    required DragStartDetails details,
    required double screenWidth,
    required double currentVolume,
    required VoidCallback onHover,
    required VoidCallback onUpdate,
  }) {
    onHover();
    if (details.globalPosition.dx < screenWidth / 2) {
      _currentDragType = DragType.brightness;
      _dragIndicatorValue = _brightnessLevel;
    } else {
      _currentDragType = DragType.volume;
      _dragIndicatorValue = currentVolume / 100.0;
    }
    _hideIndicatorTimer?.cancel();
    onUpdate();
  }

  void onVerticalDragUpdate({
    required DragUpdateDetails details,
    required double screenHeight,
    required double currentVolume,
    required ValueChanged<double> onVolumeChanged,
    required VoidCallback onUpdate,
  }) {
    if (_currentDragType == DragType.none) return;

    final delta = -(details.primaryDelta ?? 0) / screenHeight * 1.5;

    if (_currentDragType == DragType.brightness) {
      _brightnessLevel = (_brightnessLevel + delta).clamp(0.0, 1.0);
      _dragIndicatorValue = _brightnessLevel;
    } else {
      final newVol = ((currentVolume / 100.0) + delta).clamp(0.0, 1.0);
      onVolumeChanged(newVol * 100.0);
      _dragIndicatorValue = newVol;
    }
    onUpdate();
  }

  void onVerticalDragEnd({
    required VoidCallback onComplete,
    required VoidCallback onStartHideTimer,
  }) {
    _hideIndicatorTimer?.cancel();
    _hideIndicatorTimer = Timer(const Duration(milliseconds: 800), () {
      _currentDragType = DragType.none;
      onComplete();
      onStartHideTimer();
    });
  }

  void onDoubleTapDown(TapDownDetails details) {
    _doubleTapPosition = details.globalPosition;
  }

  void onDoubleTap({
    required double screenWidth,
    required ValueChanged<bool> onSkip,
  }) {
    if (_doubleTapPosition != null) {
      final isForward = _doubleTapPosition!.dx >= screenWidth / 2;
      onSkip(isForward);
    }
  }
}
