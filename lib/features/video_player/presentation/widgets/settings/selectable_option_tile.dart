import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

/// A pickable row of the player's settings (a track, a file, a source, a
/// quality): accent with a check mark when it is the current choice,
/// lighter on hover and focus; a small spinning circle while [isLoading].
class SelectableOptionTile extends StatelessWidget {
  final bool isSelected;

  /// The choice is on its way (e.g. a subtitle being fetched).
  final bool isLoading;
  final VoidCallback onTap;
  final bool autofocus;
  final EdgeInsetsGeometry padding;

  /// The check mark's colour; the accent when null.
  final Color? checkColor;
  final Widget child;

  const SelectableOptionTile({
    super.key,
    required this.isSelected,
    this.isLoading = false,
    required this.onTap,
    this.autofocus = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.checkColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // The gap sits outside the item so the focus ring hugs the tile.
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DpadFocusable(
        autofocus: autofocus,
        onTap: onTap,
        scale: 1.02,
        borderRadius: AppTheme.radius12,
        builder: (context, isFocused, isHovered, _) {
          final isHighlighted = isFocused || isHovered;
          return Container(
            padding: padding,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.accent.withValues(alpha: 0.12)
                  : isHighlighted
                  ? AppTheme.accentHoverBg
                  : AppTheme.textWhite.withValues(alpha: 0.04),
              borderRadius: AppTheme.radius12,
              border: Border.all(
                color: isSelected
                    ? AppTheme.accent.withValues(alpha: 0.5)
                    : isHighlighted
                    ? AppTheme.border
                    : AppTheme.textWhite.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Expanded(child: child),
                if (isLoading) ...[
                  const SizedBox(width: 12),
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: checkColor ?? AppTheme.accent,
                    ),
                  ),
                ] else if (isSelected) ...[
                  const SizedBox(width: 12),
                  Icon(
                    Icons.check_circle_rounded,
                    color: checkColor ?? AppTheme.accent,
                    size: 20,
                  ),
                ],
              ],
            ),
          );
        },
        child: const SizedBox.shrink(),
      ),
    );
  }
}
