import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// The end of a row whose title opens the full list: the keys' way there,
/// since the arrows pass over the title. A round arrow button with "See all"
/// under it, in the middle of a card's place; the ring goes round the circle.
class SeeAllCard extends StatelessWidget {
  final VoidCallback onTap;

  const SeeAllCard({super.key, required this.onTap});

  static const _circleSize = 56.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: DpadFocusable(
        onTap: onTap,
        // Drawn round the circle below, not round the circle and its text.
        showFocusRing: false,
        child: Builder(
          builder: (context) {
            final scope = DpadFocusScope.maybeOf(context);
            final isHighlighted = scope?.isHighlighted ?? false;
            final color = isHighlighted
                ? Theme.of(context).colorScheme.primary
                : AppTheme.textMuted;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FocusRing(
                  isVisible: scope?.isFocused ?? false,
                  borderRadius: BorderRadius.circular(_circleSize / 2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _circleSize,
                    height: _circleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isHighlighted ? color : Colors.white24,
                        width: 2,
                      ),
                    ),
                    child: Icon(LucideIcons.arrowRight, color: color, size: 26),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.carouselSeeAll,
                  style: TextStyle(
                    color: isHighlighted ? color : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
