import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';
import 'package:flutter/material.dart';

/// The "More info" pill on wide screens. It is not a button of its own: the
/// whole hero is focusable and opens the details, so the pill only shows
/// whether the hero has the focus.
class HeroMoreInfoPill extends StatelessWidget {
  final bool isHeroFocused;

  const HeroMoreInfoPill({super.key, required this.isHeroFocused});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    // The hero's own ring is off: the pill shows it (REV-252).
    return FocusRing(
      isVisible: isHeroFocused,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isHeroFocused
              ? theme.focusColor
              : AppTheme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isHeroFocused
                ? primary.withValues(alpha: 0.5)
                : AppTheme.border,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: isHeroFocused ? primary : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.homeMoreInfo,
              style: TextStyle(
                color: isHeroFocused
                    ? AppTheme.textWhite
                    : AppTheme.textSecondary,
                fontSize: 15,
                fontWeight: isHeroFocused ? FontWeight.bold : FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
