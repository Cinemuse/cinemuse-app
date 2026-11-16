import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Where a ← / → arrow press scrolls a carousel row: about one page, stopping
/// with an item lined up on the row's left padding, as the first item is at
/// rest (REV-247). Measures the real items, so rows with mixed widths (the
/// sport row's day markers) line up too.
///
/// [items] are the row's items; only the ones laid out count. [leadingPadding]
/// is the list's left padding.
double carouselArrowTarget({
  required ScrollPosition position,
  required Iterable<RenderObject?> items,
  required double leadingPadding,
  required bool isForward,
}) {
  final pixels = position.pixels;
  final viewport = position.viewportDimension;
  // Scroll offsets that put an item on the left padding, with the item's end.
  final stops = <({double offset, double end})>[];
  for (final item in items) {
    if (item == null || !item.attached) continue;
    final rowViewport = RenderAbstractViewport.maybeOf(item);
    if (rowViewport == null) continue;
    final start = rowViewport.getOffsetToReveal(item, 0.0).offset;
    final end = rowViewport.getOffsetToReveal(item, 1.0).offset + viewport;
    stops.add((offset: start - leadingPadding, end: end));
  }

  double target;
  if (isForward) {
    // The first item cut by the right edge becomes the first one.
    final next = stops
        .where(
          (s) => s.end > pixels + viewport + 0.5 && s.offset > pixels + 0.5,
        )
        .map((s) => s.offset);
    target = next.isEmpty ? position.maxScrollExtent : next.reduce(math.min);
  } else {
    // The item now first ends up cut by the right edge.
    final before = stops
        .map((s) => s.offset)
        .where((offset) => offset < pixels - 0.5)
        .toList();
    final onePageBack = before.where(
      (offset) => offset >= pixels + leadingPadding - viewport,
    );
    target = onePageBack.isNotEmpty
        ? onePageBack.reduce(math.min)
        : before.isNotEmpty
        ? before.reduce(math.max)
        : pixels + leadingPadding - viewport;
  }
  return target.clamp(0.0, position.maxScrollExtent);
}
