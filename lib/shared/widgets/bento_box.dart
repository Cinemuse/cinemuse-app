import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';

class BentoBox extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? action;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final Color? backgroundColor;
  final bool showBorder;

  const BentoBox({
    super.key,
    required this.title,
    this.icon,
    this.action,
    required this.child,
    this.padding,
    this.height,
    this.backgroundColor,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.secondary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
        border: showBorder
            ? Border.all(
                color: AppTheme.border.withOpacity(0.1),
                width: 1,
              )
            : null,
      ),
      clipBehavior: Clip.antiAlias, // Ensure children respect the rounded corners
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title.isNotEmpty || icon != null || action != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 24, 
                isMobile ? 16 : 24, 
                isMobile ? 16 : 24, 
                isMobile ? 12 : 16,
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 20,
                      color: AppTheme.accent,
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (title.isNotEmpty)
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        style: DesktopTypography.bentoHeader,
                      ),
                    ),
                  if (action != null) action!,
                ],
              ),
            ),
          // We use flexible child handling: if height is set, we pad and potentially scroll/clip.
          // If no height, we just padding and wrap.
          Padding(
            padding: padding ?? EdgeInsets.fromLTRB(
              isMobile ? 16 : 24, 
              0, 
              isMobile ? 16 : 24, 
              isMobile ? 16 : 24,
            ),
            child: height != null 
                ? SizedBox(
                    height: height! - (title.isNotEmpty ? 62 : 0), 
                    child: child
                  ) 
                : child,
          ),
        ],
      ),
    );
  }
}
