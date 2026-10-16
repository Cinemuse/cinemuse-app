import 'dart:math' as math;

/// Where the mouse is along a seekbar's `Slider` track, from 0 to 1.
///
/// The slider draws its track inset on each side by the larger of the thumb
/// and overlay radius, and a click maps over that inset track. Mapping the
/// hover over the full width showed a time a few seconds off from where the
/// click jumped, more towards both ends (REV-288).
double seekbarHoverFraction({
  required double x,
  required double width,
  required double thumbRadius,
  required double overlayRadius,
}) {
  final inset = math.max(thumbRadius, overlayRadius);
  final trackWidth = width - 2 * inset;
  if (trackWidth <= 0) return 0;
  return ((x - inset) / trackWidth).clamp(0.0, 1.0);
}
