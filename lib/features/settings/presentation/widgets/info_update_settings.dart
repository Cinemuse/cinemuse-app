import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/services/system/app_full_screen.dart';
import 'package:cinemuse_app/core/utils/platform_info.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:cinemuse_app/features/updates/application/update_service.dart';
import 'package:cinemuse_app/features/updates/domain/update_state.dart';
import 'package:cinemuse_app/features/updates/presentation/update_error_message.dart';
import 'package:cinemuse_app/features/updates/presentation/update_progress.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Info & updates category: the installed version, a new one with
/// Update now (then the download) and its notes, and Check for updates.
class InfoUpdateSettings extends ConsumerWidget {
  const InfoUpdateSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(updateProvider);
    final hasUpdate = ref.watch(hasUpdateProvider);
    final notes = state.releaseNotes;

    return SettingsSection(
      title: l10n.settingsInfoUpdates,
      description: l10n.settingsInfoUpdatesDesc,
      children: [
        SettingsCard(
          children: [
            _VersionRow(
              label: l10n.updateInstalledVersion,
              version: state.currentVersion ?? '–',
            ),
            if (hasUpdate) ...[
              const SizedBox(height: 12),
              _VersionRow(
                label: l10n.updateNewVersion,
                version: state.latestVersionLabel!,
                isNew: true,
              ),
            ],
            const SizedBox(height: 20),
            _UpdateActions(state: state, hasUpdate: hasUpdate),
          ],
        ),
        if (hasUpdate && notes != null && notes.isNotEmpty)
          _ReleaseNotesCard(version: state.latestVersionLabel!, notes: notes),
        // In full screen, or on a TV with a remote, there's no window
        // button to close it with.
        if (PlatformInfo.isDesktop)
          SettingsCard(
            children: [
              SettingsTile(
                label: l10n.settingsCloseApp,
                description: l10n.settingsCloseAppDesc,
                icon: Icons.power_settings_new,
                showDivider: false,
                onTap: () => ref.read(appWindowProvider).close(),
              ),
            ],
          ),
      ],
    );
  }
}

class _VersionRow extends StatelessWidget {
  final String label;
  final String version;
  final bool isNew;

  const _VersionRow({
    required this.label,
    required this.version,
    this.isNew = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 15),
          ),
        ),
        Text(
          version,
          style: TextStyle(
            color: isNew ? AppTheme.accent : Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// The download while it runs; otherwise the last check's outcome (or its
/// error), Update now when a new version is out, and Check for updates.
class _UpdateActions extends ConsumerWidget {
  final UpdateState state;
  final bool hasUpdate;

  const _UpdateActions({required this.state, required this.hasUpdate});

  Future<void> _check(BuildContext context, WidgetRef ref) async {
    await ref.read(updateProvider.notifier).checkForUpdates();
    if (!context.mounted) return;
    final checked = ref.read(updateProvider);
    if (checked.status != UpdateStatus.error) return;
    AppSnackBar.show(
      context,
      message: updateErrorMessage(AppLocalizations.of(context)!, checked),
      isError: true,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final status = state.status;
    if (status == UpdateStatus.downloading ||
        status == UpdateStatus.readyToInstall) {
      return const UpdateProgress();
    }
    final isChecking = status == UpdateStatus.checking;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (status == UpdateStatus.error)
          _StatusLine(
            icon: Icons.error_outline,
            text: updateErrorMessage(l10n, state),
            color: AppTheme.error,
          )
        else if (isChecking)
          _StatusLine(text: l10n.updateChecking, color: AppTheme.textMuted)
        else if (status == UpdateStatus.upToDate)
          _StatusLine(
            icon: Icons.check_circle_outline,
            text: l10n.updateUpToDate,
            color: AppTheme.success,
          ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (hasUpdate)
              ElevatedButton.icon(
                onPressed: () =>
                    ref.read(updateProvider.notifier).startUpdate(),
                icon: const Icon(Icons.system_update_alt, size: 18),
                label: Text(l10n.updateNow),
              ),
            OutlinedButton.icon(
              onPressed: isChecking ? null : () => _check(context, ref),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l10n.updateCheck),
            ),
          ],
        ),
      ],
    );
  }
}

/// One line above the buttons: an icon, or a spinner while checking.
class _StatusLine extends StatelessWidget {
  final IconData? icon;
  final String text;
  final Color color;

  const _StatusLine({this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          if (icon != null)
            Icon(icon, color: color, size: 20)
          else
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}

/// The release's notes. It takes the focus with nothing to press, so the
/// remote's Down scrolls to it.
class _ReleaseNotesCard extends StatelessWidget {
  final String version;
  final String notes;

  const _ReleaseNotesCard({required this.version, required this.notes});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DpadFocusable(
      borderRadius: BorderRadius.circular(16),
      // No margin inside the ring: it would sit away from the card.
      child: SettingsCard(
        margin: EdgeInsets.zero,
        children: [
          Text(
            l10n.updateWhatsNewIn(version),
            style: const TextStyle(
              color: AppTheme.accent,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          MarkdownBody(
            data: notes,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              h1: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              h2: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              listBullet: const TextStyle(color: AppTheme.accent),
            ),
          ),
        ],
      ),
    );
  }
}
