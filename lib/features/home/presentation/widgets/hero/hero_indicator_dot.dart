import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// One page dot under the hero; the active one is a wider glowing bar.
class HeroIndicatorDot extends StatelessWidget {
  final bool isActive;
  final bool isMobile;
  final VoidCallback onTap;

  const HeroIndicatorDot({
    super.key,
    required this.isActive,
    required this.isMobile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = isActive ? (isMobile ? 18.0 : 24.0) : (isMobile ? 6.0 : 8.0);
    final height = isMobile ? 5.0 : 6.0;

    return InkWell(
      mouseCursor: AppTheme.clickCursor,
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 4 : 6,
          vertical: 14,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: isActive
                ? theme.colorScheme.primary
                : AppTheme.textMuted.withValues(alpha: 0.4),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}
