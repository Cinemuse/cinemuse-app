import 'package:flutter/material.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';
import 'package:cinemuse_app/shared/widgets/menu/menu_focus_ring.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class SettingsSection extends StatelessWidget {
  final String title;
  final String? description;
  final List<Widget> children;

  const SettingsSection({
    super.key,
    required this.title,
    this.description,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppTheme.accent,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 4),
                Text(
                  description!,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...children,
        const SizedBox(height: 16),
      ],
    );
  }
}

class SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final CrossAxisAlignment crossAxisAlignment;

  const SettingsCard({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(24),
    this.margin = const EdgeInsets.only(bottom: 24),
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(
          16,
        ), // Increased from 12 for a smoother look
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(crossAxisAlignment: crossAxisAlignment, children: children),
    );
  }
}

class SettingsTile extends StatelessWidget {
  final String label;
  final String? description;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;
  final int descriptionMaxLines;

  const SettingsTile({
    super.key,
    required this.label,
    this.description,
    this.icon,
    this.leading,
    this.trailing,
    this.onTap,
    this.showDivider = true,
    this.descriptionMaxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        children: [
          if (leading != null || icon != null) ...[
            Container(
              width: 40,
              height: 40,
              padding: leading != null
                  ? EdgeInsets.zero
                  : const EdgeInsets.all(8),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  leading ??
                  (icon != null
                      ? Icon(icon, size: 20, color: Colors.white70)
                      : null),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!,
                    maxLines: descriptionMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 16), trailing!],
          if (onTap != null && trailing == null) ...[
            const SizedBox(width: 16),
            const Icon(
              Icons.chevron_right,
              color: AppTheme.textMuted,
              size: 20,
            ),
          ],
        ],
      ),
    );

    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor: AppTheme.clickCursor,
        onTap: onTap,
        borderRadius: BorderRadius.circular(16), // Matches the card
        child: content,
      ),
    );

    return Column(
      children: [
        // Without onTap the row can't take focus; its trailing control
        // shows its own ring. Rows sit edge to edge: the ring goes on the
        // row's edge.
        if (onTap != null)
          FocusRingFollower(
            borderRadius: BorderRadius.circular(16),
            isInside: true,
            child: tile,
          )
        else
          tile,
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withValues(alpha: 0.05),
            indent: icon != null ? 52 : 0,
          ),
      ],
    );
  }
}

/// The small drop-down at the end of a settings row.
class SettingsSmallDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const SettingsSmallDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FocusRingFollower(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(18), // 0.07 * 255
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(25)), // 0.1 * 255
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            items: withMenuFocusRings(items),
            onChanged: onChanged,
            mouseCursor: AppTheme.clickCursor,
            dropdownMenuItemMouseCursor: AppTheme.clickCursor,
            dropdownColor: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            isDense: true, // No inner padding: the 38 px box sets the height
            alignment: Alignment.center,
            icon: const Icon(
              Icons.keyboard_arrow_down,
              color: AppTheme.textMuted,
              size: 18,
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// A [SettingsSmallDropdown] of the app's languages (English, Italian),
/// plus "Original" (Japanese) first when [hasOriginal] (anime audio).
class SettingsLanguageDropdown extends StatelessWidget {
  final String value;
  final bool hasOriginal;
  final ValueChanged<String?> onChanged;

  const SettingsLanguageDropdown({
    super.key,
    required this.value,
    this.hasOriginal = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsSmallDropdown<String>(
      value: value,
      items: [
        if (hasOriginal)
          DropdownMenuItem(value: 'ja', child: Text(l10n.settingsOriginal)),
        DropdownMenuItem(value: 'en', child: Text(l10n.settingsEnglish)),
        DropdownMenuItem(value: 'it', child: Text(l10n.settingsItalian)),
      ],
      onChanged: onChanged,
    );
  }
}
