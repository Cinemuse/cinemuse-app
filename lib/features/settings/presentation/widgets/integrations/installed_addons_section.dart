import 'dart:async';

import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/save_settings.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_toggle.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:cinemuse_app/features/streaming/models/stremio_addon.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// The installed Stremio add-ons: on / off, copy link, remove (with Undo).
class InstalledAddonsSection extends ConsumerWidget {
  const InstalledAddonsSection({super.key});

  /// Removes [addon] with an Undo snackbar (REV-78). Runs here, not in the
  /// row: the row is gone with the add-on, this section stays.
  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    StremioAddon addon,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final index = ref
        .read(settingsProvider)
        .installedAddons
        .indexWhere((a) => a.id == addon.id);

    await runSettingsSave(context, ref, (s) => s.removeAddon(addon.id));
    if (!context.mounted) return;
    final isRemoved = !ref
        .read(settingsProvider)
        .installedAddons
        .any((a) => a.id == addon.id);
    if (!isRemoved) return; // the save failed and said so

    AppSnackBar.show(
      context,
      message: l10n.settingsAddonRemoved(addon.name),
      actionLabel: l10n.commonUndo,
      onAction: () {
        // Undo needs this screen's context for its error message.
        if (!context.mounted) return;
        unawaited(
          runSettingsSave(context, ref, (s) => s.restoreAddon(addon, index)),
        );
      },
    );
  }

  void _copyLink(BuildContext context, StremioAddon addon) {
    unawaited(Clipboard.setData(ClipboardData(text: addon.baseUrl)));
    AppSnackBar.show(
      context,
      message: AppLocalizations.of(context)!.settingsCopiedToClipboard,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final addons = ref.watch(settingsProvider.select((s) => s.installedAddons));

    if (addons.isEmpty) return const _NoAddonsCard();

    return SettingsSection(
      title: l10n.settingsInstalledAddons,
      children: [
        SettingsCard(
          padding: EdgeInsets.zero,
          children: [
            for (final addon in addons)
              _AddonTile(
                addon: addon,
                showDivider: addon != addons.last,
                onToggle: (isEnabled) => runSettingsSave(
                  context,
                  ref,
                  (settings) => settings.toggleAddon(addon.id, isEnabled),
                ),
                onCopy: () => _copyLink(context, addon),
                onRemove: () => _remove(context, ref, addon),
              ),
          ],
        ),
      ],
    );
  }
}

class _AddonTile extends StatelessWidget {
  final StremioAddon addon;
  final bool showDivider;
  final ValueChanged<bool> onToggle;
  final VoidCallback onCopy;
  final VoidCallback onRemove;

  const _AddonTile({
    required this.addon,
    required this.showDivider,
    required this.onToggle,
    required this.onCopy,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const fallbackIcon = Icon(LucideIcons.box, size: 20, color: Colors.white70);
    final logo = addon.logo;

    return SettingsTile(
      label: addon.name,
      description: addon.baseUrl,
      leading: logo != null && logo.isNotEmpty
          ? Image.network(
              logo,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => fallbackIcon,
            )
          : fallbackIcon,
      // The whole row flips the switch; the buttons keep their own taps.
      onTap: () => onToggle(!addon.enabled),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SettingSwitch(value: addon.enabled),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(
              LucideIcons.copy,
              color: AppTheme.textMuted,
              size: 18,
            ),
            onPressed: onCopy,
            tooltip: l10n.settingsCopy,
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(
              LucideIcons.trash2,
              color: Colors.redAccent,
              size: 18,
            ),
            onPressed: onRemove,
            tooltip: l10n.settingsRemove,
          ),
          const SizedBox(width: 4),
        ],
      ),
      showDivider: showDivider,
    );
  }
}

class _NoAddonsCard extends StatelessWidget {
  const _NoAddonsCard();

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                Icon(
                  LucideIcons.box,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.settingsNoAddons,
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
