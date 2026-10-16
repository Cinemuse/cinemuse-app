import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> {
  @override
  void initState() {
    super.initState();
    _SkeletonPulse.attach();
  }

  @override
  void dispose() {
    _SkeletonPulse.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _SkeletonPulse.opacity,
      builder: (context, opacity, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// One pulse shared by every skeleton on screen (REV-41): a loading row has
/// a dozen boxes, and one animation each meant a dozen tickers. Runs only
/// while at least one box is shown.
abstract final class _SkeletonPulse {
  static const _halfCycle = Duration(milliseconds: 1500);
  static const _minOpacity = 0.05;
  static const _maxOpacity = 0.12;

  static final opacity = ValueNotifier<double>(_minOpacity);
  static Ticker? _ticker;
  static int _boxCount = 0;

  static void attach() {
    if (_boxCount++ == 0) _ticker = Ticker(_onTick)..start();
  }

  static void detach() {
    if (--_boxCount > 0) return;
    _ticker?.dispose();
    _ticker = null;
    opacity.value = _minOpacity;
  }

  static void _onTick(Duration elapsed) {
    // 0 → 1 → 0 every two half cycles, eased like the old repeat(reverse).
    final t = elapsed.inMicroseconds / _halfCycle.inMicroseconds;
    final phase = t % 2;
    final linear = phase <= 1 ? phase : 2 - phase;
    final eased = Curves.easeInOut.transform(math.min(linear, 1.0));
    opacity.value = _minOpacity + (_maxOpacity - _minOpacity) * eased;
  }
}
