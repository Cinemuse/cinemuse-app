import 'dart:math' as math;

import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// One leaf of the wreath, on a wreath 200 wide.
class WreathLeaf {
  /// The score that lights it, 1 to 10.
  final int value;
  final bool isLeft;
  final Color color;
  final Offset center;

  /// Clockwise, in radians, from the leaf standing upright.
  final double angle;

  const WreathLeaf({
    required this.value,
    required this.isLeft,
    required this.color,
    required this.center,
    required this.angle,
  });

  bool isLitAt(int score) => score >= value;
}

/// The ten leaves, five per side, lighting from the bottom, left then right.
final List<WreathLeaf> wreathLeaves = _buildLeaves();

List<WreathLeaf> _buildLeaves() {
  const radius = 72.0;
  return [
    for (var step = 0; step < 5; step++)
      for (final isLeft in const [true, false])
        () {
          final around = (22 + step * 31) * math.pi / 180;
          final side = isLeft ? -1 : 1;
          return WreathLeaf(
            value: step * 2 + (isLeft ? 1 : 2),
            isLeft: isLeft,
            color: (isLeft
                ? AppTheme.wreathLeftLeaves
                : AppTheme.wreathRightLeaves)[step],
            center: Offset(
              100 + side * radius * math.sin(around),
              100 + radius * math.cos(around),
            ),
            // Along the circle, then tipped outwards.
            angle:
                math.atan2(side * math.cos(around), math.sin(around)) +
                side * 16 * math.pi / 180,
          );
        }(),
  ];
}

/// The user's own score: an open wreath of ten leaves, one per point. It only
/// shows the score; outside reviews keep their stars out of 5.
class Wreath extends StatelessWidget {
  /// 0 (every leaf empty) to 10.
  final int score;
  final double size;

  /// The number in the middle: only where the wreath is big enough.
  final bool showNumber;

  const Wreath({
    super.key,
    required this.score,
    required this.size,
    this.showNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: AppLocalizations.of(context)!.ownReviewScoreLabel(score),
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _WreathPainter(score),
            child: showNumber
                ? Center(
                    child: Text(
                      '$score',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: size * 0.26,
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _WreathPainter extends CustomPainter {
  final int score;

  const _WreathPainter(this.score);

  // The leaf's outline in a box 40 wide and 64 tall, centred on its middle.
  static final _leaf = Path()
    ..moveTo(0, -30)
    ..cubicTo(14, -16, 16, 8, 0, 30)
    ..cubicTo(-16, 8, -14, -16, 0, -30)
    ..close();

  /// The leaf's size on a wreath 200 wide, against its 40 x 64 box.
  static const _leafScale = 0.58;
  static const _outlineWidth = 3.0;

  /// Below this a leaf's glow only blurs it.
  static const _smallestGlowingSize = 80.0;

  /// In screen pixels: thinner, an empty wreath in a badge would disappear.
  static const _thinnestOutline = 0.75;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 200;
    final scale = _leafScale * unit;
    final outlineWidth = math.max(_outlineWidth, _thinnestOutline / scale);

    for (final leaf in wreathLeaves) {
      final isLit = leaf.isLitAt(score);
      canvas
        ..save()
        ..translate(leaf.center.dx * unit, leaf.center.dy * unit)
        ..rotate(leaf.angle)
        ..scale(scale);

      if (isLit && size.width >= _smallestGlowingSize) {
        canvas.drawPath(
          _leaf,
          Paint()
            ..color = leaf.color
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 / scale),
        );
      }
      if (isLit) canvas.drawPath(_leaf, Paint()..color = leaf.color);
      canvas
        ..drawPath(
          _leaf,
          Paint()
            ..color = isLit ? leaf.color : AppTheme.wreathEmptyLeaf
            ..style = PaintingStyle.stroke
            ..strokeWidth = outlineWidth
            ..strokeJoin = StrokeJoin.round,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_WreathPainter oldDelegate) => oldDelegate.score != score;
}
