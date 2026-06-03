import 'package:flutter/material.dart';
import 'package:cinemuse_app/shared/widgets/hover_scale.dart';

class AppBackButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color iconColor;
  final double padding;

  const AppBackButton({
    super.key,
    required this.onTap,
    this.backgroundColor,
    this.iconColor = Colors.white,
    this.padding = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: HoverScale(
          child: Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Icon(Icons.arrow_back, color: iconColor, size: 20),
          ),
        ),
      ),
    );
  }
}
