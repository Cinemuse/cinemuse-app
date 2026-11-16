import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// The app-wide [ScrollBehavior]: Material defaults, with a gap-tolerant
/// velocity tracker for trackpads so a trackpad swipe keeps its glide.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  GestureVelocityTrackerBuilder velocityTrackerBuilder(BuildContext context) {
    final GestureVelocityTrackerBuilder base = super.velocityTrackerBuilder(
      context,
    );
    return (PointerEvent event) => event.kind == PointerDeviceKind.trackpad
        ? TrackpadVelocityTracker()
        : base(event);
  }
}

/// A [VelocityTracker] that accepts longer gaps between trackpad samples
/// (REV-254).
///
/// Windows reads the trackpad on a ~16 ms `WM_TIMER`, and since Flutter 3.35
/// the Dart UI runs on that same thread: a frame longer than 40 ms (Explore
/// building new cards) delays the samples. The default tracker then reads the
/// gap as "the fingers had stopped" and returns zero speed, so the glide only
/// happens when the app was idle.
class TrackpadVelocityTracker extends VelocityTracker {
  TrackpadVelocityTracker() : super.withKind(PointerDeviceKind.trackpad);

  static const int _assumeStoppedMilliseconds = 100;
  static const int _horizonMilliseconds = 200;
  static const int _historySize = 20;
  static const int _minSampleSize = 3;

  final Stopwatch _sinceLastSample = GestureBinding.instance.samplingClock
      .stopwatch();
  final List<({Offset point, Duration time})> _samples = [];

  @override
  void addPosition(Duration time, Offset position) {
    _sinceLastSample
      ..start()
      ..reset();
    _samples.add((point: position, time: time));
    if (_samples.length > _historySize) _samples.removeAt(0);
  }

  @override
  VelocityEstimate? getVelocityEstimate() {
    if (_samples.isEmpty) return null;
    const stopped = VelocityEstimate(
      pixelsPerSecond: Offset.zero,
      confidence: 1.0,
      duration: Duration.zero,
      offset: Offset.zero,
    );
    if (_sinceLastSample.elapsedMilliseconds > _assumeStoppedMilliseconds) {
      return stopped;
    }

    final newest = _samples.last;
    final x = <double>[], y = <double>[], w = <double>[], t = <double>[];
    var oldest = newest;
    var previous = newest;
    for (final sample in _samples.reversed) {
      final double age = (newest.time - sample.time).inMicroseconds / 1000;
      final double gap = (previous.time - sample.time).inMicroseconds / 1000;
      previous = sample;
      if (age > _horizonMilliseconds || gap > _assumeStoppedMilliseconds) {
        break;
      }
      oldest = sample;
      x.add(sample.point.dx);
      y.add(sample.point.dy);
      w.add(1.0);
      t.add(-age);
    }

    final duration = newest.time - oldest.time;
    final offset = newest.point - oldest.point;
    if (t.length >= _minSampleSize) {
      final PolynomialFit? xFit = LeastSquaresSolver(t, x, w).solve(2);
      final PolynomialFit? yFit = LeastSquaresSolver(t, y, w).solve(2);
      if (xFit != null && yFit != null) {
        return VelocityEstimate(
          // Pixels per millisecond to pixels per second.
          pixelsPerSecond: Offset(
            xFit.coefficients[1] * 1000,
            yFit.coefficients[1] * 1000,
          ),
          confidence: xFit.confidence * yFit.confidence,
          duration: duration,
          offset: offset,
        );
      }
    }
    return VelocityEstimate(
      pixelsPerSecond: Offset.zero,
      confidence: 1.0,
      duration: duration,
      offset: offset,
    );
  }
}
