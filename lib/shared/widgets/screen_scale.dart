import 'package:flutter/widgets.dart';

/// Draws [child] [scale] times its normal size: below 1 the app lays itself
/// out for a wider screen and is shrunk to fit (a TV, which Android counts
/// as only 960 wide), above 1 for a narrower one and enlarged. Text stays
/// sharp: it is drawn at the screen's own resolution.
class ScreenScale extends StatelessWidget {
  final double scale;
  final Widget child;

  const ScreenScale({super.key, required this.scale, required this.child});

  @override
  Widget build(BuildContext context) {
    if (scale == 1) return child;
    final media = MediaQuery.of(context);
    final size = media.size / scale;
    return FittedBox(
      fit: BoxFit.fill,
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(
        size: size,
        child: MediaQuery(
          data: media.copyWith(
            size: size,
            devicePixelRatio: media.devicePixelRatio * scale,
            padding: media.padding / scale,
            viewPadding: media.viewPadding / scale,
            viewInsets: media.viewInsets / scale,
            systemGestureInsets: media.systemGestureInsets / scale,
          ),
          child: child,
        ),
      ),
    );
  }
}
