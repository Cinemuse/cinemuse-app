import 'package:cinemuse_app/features/live_tv/presentation/widgets/playlist_management_sheet.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/save_settings.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_toggle.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Live TV category: buffer, disk cache and the playlists.
class LiveTvSettings extends ConsumerWidget {
  const LiveTvSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final save = settingsSaver(context, ref);
    final l10n = AppLocalizations.of(context)!;
    final userSettings = ref.watch(settingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSection(
          title: l10n.settingsLiveTv,
          children: [
            SettingsCard(
              children: [
                SettingsTile(
                  label: l10n.settingsLiveTvBufferSize,
                  description: l10n.settingsLiveTvBufferSizeDesc,
                  icon: Icons.history,
                  trailing: SettingsSmallDropdown<int>(
                    value: userSettings.liveTvBufferSize,
                    items: const [
                      DropdownMenuItem(value: 256, child: Text('256 MB')),
                      DropdownMenuItem(value: 512, child: Text('512 MB')),
                      DropdownMenuItem(value: 1024, child: Text('1 GB')),
                      DropdownMenuItem(value: 2048, child: Text('2 GB')),
                    ],
                    onChanged: (val) =>
                        save((s) => s.copyWith(liveTvBufferSize: val)),
                  ),
                ),
                SettingsToggleTile(
                  label: l10n.settingsLiveTvDiskCache,
                  description: l10n.settingsLiveTvDiskCacheDesc,
                  icon: Icons.save,
                  showDivider: false,
                  value: userSettings.enableLiveTvDiskCache,
                  onChanged: (val) =>
                      save((s) => s.copyWith(enableLiveTvDiskCache: val)),
                ),
              ],
            ),
          ],
        ),
        SettingsSection(
          title: l10n.liveTvCustomPlaylists,
          description: l10n.liveTvCustomPlaylistsDesc,
          children: [
            SettingsCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: const [PlaylistListSection()],
            ),
          ],
        ),
      ],
    );
  }
}
