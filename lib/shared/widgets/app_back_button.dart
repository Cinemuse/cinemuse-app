import 'package:flutter/material.dart';
import 'package:cinemuse_app/shared/widgets/hover_scale.dart';

class AppBackButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color iconColor;
  final double padding;

  const AppBackButton({
    super.key,
    required this.onTap,
    this.backgroundColor = Colors.black54,
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
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Icon(Icons.chevron_left, color: iconColor, size: 24),
          ),
        ),
      ),
    );
  }
}
