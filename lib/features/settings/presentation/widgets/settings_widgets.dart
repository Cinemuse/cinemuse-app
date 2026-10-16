import 'package:flutter/material.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';

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

  const SettingsTile({
    super.key,
    required this.label,
    this.description,
    this.icon,
    this.leading,
    this.trailing,
    this.onTap,
    this.showDivider = true,
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
                    maxLines: 1,
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
        // shows its own ring.
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
