import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/save_settings.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_input.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_toggle.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// The OpenSubtitles key and the auto-download switch.
class OpenSubtitlesSection extends ConsumerWidget {
  const OpenSubtitlesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final save = settingsSaver(context, ref);
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);

    return SettingsSection(
      title: l10n.settingsOpenSubtitlesTitle,
      children: [
        SettingsCard(
          children: [
            SettingsTile(
              label: l10n.settingsOpenSubtitlesTitle,
              description: l10n.settingsOpenSubtitlesKeyDesc,
              icon: LucideIcons.subtitles,
              showDivider: false,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: SettingInput(
                value: settings.openSubtitlesKey,
                placeholder: l10n.settingsOpenSubtitlesKey,
                isPassword: true,
                onSave: (val) => ref
                    .read(settingsProvider.notifier)
                    .updateSettings(
                      (s) => s.copyWith(openSubtitlesKey: val.trim()),
                    ),
              ),
            ),
            SettingsToggleTile(
              label: l10n.settingsOpenSubtitlesAutoDownloadTitle,
              description: l10n.settingsOpenSubtitlesAutoDownloadDesc,
              // A long hint: the quota warning must stay readable.
              descriptionMaxLines: 3,
              value: settings.autoDownloadMissingSubtitles,
              showDivider: false,
              onChanged: (val) =>
                  save((s) => s.copyWith(autoDownloadMissingSubtitles: val)),
            ),
          ],
        ),
      ],
    );
  }
}
