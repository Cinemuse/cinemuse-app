import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:flutter/material.dart';

/// The phone hero's buttons: "Play now" and the round "More info" button.
class HeroActionButtons extends StatelessWidget {
  final VoidCallback onPlay;
  final VoidCallback onDetails;

  const HeroActionButtons({
    super.key,
    required this.onPlay,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return FocusTraversalGroup(
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: onPlay,
            icon: const Icon(Icons.play_arrow_rounded, size: 24),
            label: Text(l10n.detailsPlayNow),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: AppTheme.textWhite,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              textStyle: theme.textTheme.bodyMedium!.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              shape: const StadiumBorder(),
              elevation: 6,
              shadowColor: primary.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(width: 14),

          // Sleek Circular Glass Info Button
          Tooltip(
            message: l10n.homeMoreInfo,
            child: DpadFocusable(
              onTap: onDetails,
              borderRadius: AppTheme.radiusFull,
              child: const SizedBox.shrink(),
              builder: (context, isFocused, isHovered, _) {
                final isHighlighted = isFocused || isHovered;
                return Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isHighlighted
                        ? theme.focusColor
                        : AppTheme.accent.withValues(alpha: 0.12),
                    border: Border.all(
                      color: isHighlighted
                          ? primary.withValues(alpha: 0.5)
                          : AppTheme.border,
                      width: 1.0,
                    ),
                    boxShadow: AppTheme.shadowCard,
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: AppTheme.textWhite,
                    size: 22,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
