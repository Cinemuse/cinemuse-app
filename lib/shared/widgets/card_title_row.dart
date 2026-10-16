import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/shared/widgets/premium_hover_text.dart';
import 'package:flutter/material.dart';

/// The line under a card's picture: its title and the "⋮" menu button, and
/// an optional muted line below (e.g. "S2 E5 · Pilot" … "23 min left").
///
/// While the card is hovered or focused the title turns pink and the button
/// shows (on phones the button always shows). Must sit inside the card's
/// [DpadFocusable].
class CardTitleRow extends StatelessWidget {
  final String title;

  /// Null hides the "⋮" button (a card with nothing in its menu).
  final VoidCallback? onMenu;

  /// Put on the "⋮" button, so the menu opens next to it.
  final Key menuAnchorKey;
  final double menuIconSize;

  /// The full title shows after a long hover (poster cards, whose titles are
  /// short on space).
  final bool showsFullTitleOnHover;
  final int maxLines;

  /// The muted line under the title, cut with "…" when long.
  final String? subtitle;

  /// Shown at the end of the muted line, never cut.
  final String? subtitleEnd;

  const CardTitleRow({
    super.key,
    required this.title,
    required this.onMenu,
    required this.menuAnchorKey,
    this.menuIconSize = 16,
    this.showsFullTitleOnHover = false,
    this.maxLines = 1,
    this.subtitle,
    this.subtitleEnd,
  });

  @override
  Widget build(BuildContext context) {
    final isHighlighted =
        DpadFocusScope.maybeOf(context)?.isHighlighted ?? false;
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium!.copyWith(
      color: isHighlighted ? theme.colorScheme.primary : Colors.white,
      fontWeight: FontWeight.w600,
      fontSize: 14,
    );

    final titleRow = Row(
      children: [
        Expanded(
          child: showsFullTitleOnHover
              ? PremiumHoverText(text: title, style: style)
              : Text(
                  title,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
        ),
        if (onMenu != null)
          AnimatedOpacity(
            opacity: (isHighlighted || Breakpoints.isCompact(context))
                ? 1.0
                : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Material(
              color: Colors.transparent,
              child: Tooltip(
                message: AppLocalizations.of(context)!.menuMoreOptions,
                child: InkWell(
                  canRequestFocus: false,
                  excludeFromSemantics: true,
                  onTap: onMenu,
                  mouseCursor: SystemMouseCursors.click,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    key: menuAnchorKey,
                    padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
                    child: Icon(
                      Icons.more_vert,
                      color: Colors.white60,
                      size: menuIconSize,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    if (subtitle == null && subtitleEnd == null) return titleRow;

    final mutedStyle = theme.textTheme.bodySmall!.copyWith(
      color: AppTheme.textMuted,
      fontSize: 12,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        titleRow,
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: Text(
                subtitle ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: mutedStyle,
              ),
            ),
            if (subtitleEnd != null) ...[
              const SizedBox(width: 8),
              Text(subtitleEnd!, maxLines: 1, style: mutedStyle),
            ],
          ],
        ),
      ],
    );
  }
}
