import 'package:flutter/material.dart';

class ResponsiveDetailsLayout extends StatelessWidget {
  final Widget mainContent;
  final Widget sidebar;
  final double spacing;
  final double mobileBreakpoint;

  const ResponsiveDetailsLayout({
    super.key,
    required this.mainContent,
    required this.sidebar,
    this.spacing = 24.0,
    this.mobileBreakpoint = 600.0,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < mobileBreakpoint;

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          mainContent,
          SizedBox(height: spacing * 1.5),
          sidebar,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: mainContent,
        ),
        SizedBox(width: spacing),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 320, maxWidth: 420),
          child: sidebar,
        ),
      ],
    );
  }
}
