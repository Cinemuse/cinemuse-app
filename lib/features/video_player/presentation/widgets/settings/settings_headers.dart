import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

/// The title of the player's settings panel when it has no tabs (live
/// TV).
class SettingsPanelTitle extends StatelessWidget {
  final String text;
  const SettingsPanelTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: AppTheme.textWhite.withValues(alpha: 0.9),
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }
}

/// The small title above a list of a panel (e.g. "Internal tracks").
class SettingsSectionTitle extends StatelessWidget {
  final String text;
  const SettingsSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// A folder row that opens and closes the list under it (a torrent's
/// files, the subtitles of one language).
class SettingsAccordionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isExpanded;
  final VoidCallback onTap;
  final bool compact;

  const SettingsAccordionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isExpanded,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return DpadFocusable(
      onTap: onTap,
      borderRadius: AppTheme.radius12,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 8,
          vertical: compact ? 8 : 12,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.folder_open_rounded,
              color: AppTheme.accent,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.textWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppTheme.textMuted.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
