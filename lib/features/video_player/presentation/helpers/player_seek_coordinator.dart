import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';

/// Coordinates virtual scrub position, fast-forward/rewind skip calculation,
/// and feedback HUD indicator timers for [CustomVideoControls].
class PlayerSeekCoordinator {
  bool _dragging = false;
  Duration? _virtualPosition;
  Timer? _clearVirtualPositionTimer;
  bool _showSeekIndicator = false;
  int _seekAmount = 0;
  Timer? _seekIndicatorTimer;

  bool get dragging => _dragging;
  Duration? get virtualPosition => _virtualPosition;
  bool get showSeekIndicator => _showSeekIndicator;
  int get seekAmount => _seekAmount;

  void dispose() {
    _clearVirtualPositionTimer?.cancel();
    _clearVirtualPositionTimer = null;
    _seekIndicatorTimer?.cancel();
    _seekIndicatorTimer = null;
  }

  void performRealSkip({
    required Player player,
    required void Function(Duration target) onSeek,
    required bool forward,
    required VoidCallback onUpdate,
    VoidCallback? onHover,
    bool showControls = true,
  }) {
    showSeekFeedback(forward: forward, onUpdate: onUpdate);
    final currentPos = _virtualPosition ?? player.state.position;
    final duration = player.state.duration;
    final target = Duration(
      seconds: (currentPos.inSeconds + (forward ? 10 : -10)).clamp(
        0,
        duration.inSeconds,
      ),
    );
    _virtualPosition = target;
    onSeek(target);
    onUpdate();

    _clearVirtualPositionTimer?.cancel();
    _clearVirtualPositionTimer = Timer(const Duration(milliseconds: 600), () {
      _virtualPosition = null;
      onUpdate();
    });
    if (showControls && onHover != null) {
      onHover();
    }
  }

  void showSeekFeedback({
    required bool forward,
    required VoidCallback onUpdate,
  }) {
    _seekIndicatorTimer?.cancel();
    _showSeekIndicator = true;
    if (forward) {
      _seekAmount = (_seekAmount > 0) ? _seekAmount + 10 : 10;
    } else {
      _seekAmount = (_seekAmount < 0) ? _seekAmount - 10 : -10;
    }
    onUpdate();

    _seekIndicatorTimer = Timer(const Duration(milliseconds: 1000), () {
      _showSeekIndicator = false;
      _seekAmount = 0;
      onUpdate();
    });
  }

  void onSeekStart({
    required double value,
    required VoidCallback onCancelHideTimer,
    required VoidCallback onUpdate,
  }) {
    _dragging = true;
    _virtualPosition = Duration(seconds: value.toInt());
    onCancelHideTimer();
    _clearVirtualPositionTimer?.cancel();
    onUpdate();
  }

  void onSeekEnd({
    required double value,
    required void Function(Duration target) onSeek,
    required VoidCallback onStartHideTimer,
    required VoidCallback onUpdate,
  }) {
    final target = Duration(seconds: value.toInt());
    onSeek(target);
    _dragging = false;
    _virtualPosition = target;
    onStartHideTimer();
    _clearVirtualPositionTimer?.cancel();
    _clearVirtualPositionTimer = Timer(const Duration(milliseconds: 500), () {
      _virtualPosition = null;
      onUpdate();
    });
    onUpdate();
  }

  void onSeekChanged({
    required double value,
    required VoidCallback onUpdate,
  }) {
    _virtualPosition = Duration(seconds: value.toInt());
    onUpdate();
  }
}
