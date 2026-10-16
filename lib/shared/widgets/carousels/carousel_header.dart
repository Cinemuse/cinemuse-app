import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:flutter/material.dart';

/// The title above a carousel row ("Trending ›").
///
/// With [onTap] the title is a link to the full list: it turns pink on mouse
/// hover and remote focus, and shows the focus ring on remote focus
/// (`PROJECT.md` → App decisions, focus and hover).
class CarouselHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;

  /// A grey icon before the title, not part of the link.
  final IconData? icon;

  /// The smaller title of the boxed Profile rows.
  final bool isSmall;

  const CarouselHeader({
    super.key,
    required this.title,
    this.onTap,
    this.icon,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: onTap == null
              ? _HeaderLabel(title: title, isSmall: isSmall)
              : DpadFocusable(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: _HeaderLabel(
                      title: title,
                      isSmall: isSmall,
                      hasChevron: true,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _HeaderLabel extends StatelessWidget {
  final String title;
  final bool isSmall;
  final bool hasChevron;

  const _HeaderLabel({
    required this.title,
    required this.isSmall,
    this.hasChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHighlighted =
        DpadFocusScope.maybeOf(context)?.isHighlighted ?? false;
    final pink = theme.colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: isHighlighted ? pink : AppTheme.textWhite,
              fontSize: isSmall ? 16 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (hasChevron) ...[
          SizedBox(width: isSmall ? 6 : 8),
          Icon(
            Icons.chevron_right,
            color: isHighlighted
                ? pink
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            size: isSmall ? 20 : 24,
          ),
        ],
      ],
    );
  }
}
