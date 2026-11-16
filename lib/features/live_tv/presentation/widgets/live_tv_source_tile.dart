import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/live_tv/data/local_playlist_storage.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_source.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_toggle.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

/// One playlist or guide in the Playlists & EPGs lists: on / off, open its
/// file or link, remove. When its last load failed, an icon by the name and
/// the reason in place of [subtitle].
class LiveTvSourceTile extends StatelessWidget {
  final LiveTvSource source;
  final String subtitle;
  final String badgeLabel;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  /// Why the last load failed, or `null`.
  final String? problem;

  /// The problem is a warning (a saved copy is still shown), not an error.
  final bool isProblemWarning;

  const LiveTvSourceTile({
    super.key,
    required this.source,
    required this.subtitle,
    required this.badgeLabel,
    required this.onToggle,
    required this.onRemove,
    this.problem,
    this.isProblemWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEnabled = source.isEnabled;
    final problem = this.problem;
    final problemColor = isProblemWarning ? AppTheme.warning : AppTheme.error;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isEnabled ? 1.0 : 0.5,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEnabled
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.03),
          ),
        ),
        child: Row(
          children: [
            // Type icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isEnabled
                    ? AppTheme.accent.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                source.isLocal ? LucideIcons.fileText : LucideIcons.globe,
                size: 20,
                color: isEnabled ? AppTheme.accent : Colors.white30,
              ),
            ),
            const SizedBox(width: 14),
            // Name + subtitle + badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          source.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (problem != null) ...[
                        const SizedBox(width: 6),
                        Icon(
                          isProblemWarning
                              ? LucideIcons.alertTriangle
                              : LucideIcons.alertCircle,
                          size: 15,
                          color: problemColor,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    problem ?? subtitle,
                    style: TextStyle(
                      color: problem != null
                          ? problemColor
                          : Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                    ),
                    maxLines: problem != null ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  _TypeBadge(label: badgeLabel),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Actions row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SettingToggle(value: isEnabled, onChanged: (_) => onToggle()),
                const SizedBox(width: 4),
                if (source.isLocal && (Platform.isWindows || Platform.isLinux))
                  _OpenFolderButton(source: source, l10n: l10n),
                if (!source.isLocal && !source.isBuiltIn)
                  _OpenLinkButton(source: source, l10n: l10n),
                const SizedBox(width: 4),
                // The Cinemuse entry can only be turned off.
                if (!source.isBuiltIn)
                  IconButton(
                    icon: const Icon(LucideIcons.trash2, size: 17),
                    color: Colors.redAccent,
                    tooltip: l10n.settingsRemove,
                    onPressed: onRemove,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Type badge chip
// ---------------------------------------------------------------------------

class _TypeBadge extends StatelessWidget {
  final String label;

  const _TypeBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Open folder button (desktop, local files only)
// ---------------------------------------------------------------------------

class _OpenFolderButton extends StatelessWidget {
  final LiveTvSource source;
  final AppLocalizations l10n;

  const _OpenFolderButton({required this.source, required this.l10n});

  Future<void> _openFolder(BuildContext context) async {
    try {
      final absolutePath = await LocalPlaylistStorage.resolveToAbsolutePath(
        source.urlOrPath,
      );
      if (Platform.isWindows) {
        await Process.run('explorer', ['/select,', absolutePath]);
      } else if (Platform.isLinux) {
        final dirPath = p.dirname(absolutePath);
        await Process.run('xdg-open', [dirPath]);
      }
    } catch (e, s) {
      // Only the error type: the path or URL can hold login details.
      AppLogger.warn(
        'PlaylistListSection',
        'Failed to open the file location',
        error: e.runtimeType,
        stackTrace: s,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(LucideIcons.folderOpen, size: 17),
      color: AppTheme.textMuted,
      hoverColor: AppTheme.accentHoverBg,
      tooltip: l10n.liveTvOpenFileLocation,
      onPressed: () => _openFolder(context),
    );
  }
}

// ---------------------------------------------------------------------------
// Open link button (links only)
// ---------------------------------------------------------------------------

class _OpenLinkButton extends StatelessWidget {
  final LiveTvSource source;
  final AppLocalizations l10n;

  const _OpenLinkButton({required this.source, required this.l10n});

  Future<void> _openLink() async {
    try {
      final uri = Uri.parse(source.urlOrPath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e, s) {
      AppLogger.warn(
        'PlaylistListSection',
        'Failed to open the URL',
        error: e.runtimeType,
        stackTrace: s,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(LucideIcons.externalLink, size: 17),
      color: AppTheme.textMuted,
      hoverColor: AppTheme.accentHoverBg,
      tooltip: l10n.liveTvOpenLink,
      onPressed: _openLink,
    );
  }
}
