import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/save_settings.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_input.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_toggle.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Real-Debrid and TorBox: on / off, their keys, and which one goes first.
class DebridSection extends ConsumerWidget {
  const DebridSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final save = settingsSaver(context, ref);
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return SettingsSection(
      title: l10n.settingsDebridServices,
      children: [
        SettingsCard(
          children: [
            SettingsToggleTile(
              label: l10n.settingsRealDebridTitle,
              description: l10n.settingsRealDebridKeyDesc,
              icon: LucideIcons.hardDrive,
              value: settings.enableRealDebrid,
              onChanged: (val) =>
                  save((s) => s.copyWith(enableRealDebrid: val)),
            ),
            if (settings.enableRealDebrid)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: SettingInput(
                  value: settings.realDebridKey,
                  placeholder: l10n.settingsRealDebridKey,
                  isPassword: true,
                  onSave: (val) => notifier.updateSettings(
                    (s) => s.copyWith(realDebridKey: val.trim()),
                  ),
                ),
              ),
            SettingsToggleTile(
              label: l10n.settingsTorBoxTitle,
              description: l10n.settingsTorBoxKeyDesc,
              icon: LucideIcons.box,
              value: settings.enableTorBox,
              onChanged: (val) => save((s) => s.copyWith(enableTorBox: val)),
            ),
            if (settings.enableTorBox)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: SettingInput(
                  value: settings.torBoxKey,
                  placeholder: l10n.settingsTorBoxKey,
                  isPassword: true,
                  onSave: (val) => notifier.updateSettings(
                    (s) => s.copyWith(torBoxKey: val.trim()),
                  ),
                ),
              ),
            if (settings.enableRealDebrid && settings.enableTorBox)
              SettingsTile(
                label: l10n.settingsPreferredDebridTitle,
                description: l10n.settingsPreferredDebridDesc,
                icon: Icons.swap_vert_rounded,
                trailing: SettingsSmallDropdown<String>(
                  value:
                      settings.preferredDebridProvider.toLowerCase() == 'torbox'
                      ? 'torbox'
                      : 'realdebrid',
                  // Brand names: the same in every language.
                  items: const [
                    DropdownMenuItem(
                      value: 'realdebrid',
                      child: Text('Real-Debrid'),
                    ),
                    DropdownMenuItem(value: 'torbox', child: Text('TorBox')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      save((s) => s.copyWith(preferredDebridProvider: val));
                    }
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }
}
