import 'package:cinemuse_app/features/live_tv/presentation/widgets/playlist_management_sheet.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_choice.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/save_settings.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Live TV category: the rewind length and the playlists.
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
                SettingsChoiceTile<int>(
                  label: l10n.settingsLiveTvRewind,
                  description: l10n.settingsLiveTvRewindDesc,
                  icon: Icons.history,
                  showDivider: false,
                  value: userSettings.liveTvRewindMinutes,
                  choices: [
                    for (final minutes in UserSettings.liveTvRewindChoices)
                      SettingsChoice(
                        minutes,
                        l10n.settingsLiveTvRewindMinutes(minutes),
                      ),
                  ],
                  onChanged: (val) =>
                      save((s) => s.copyWith(liveTvRewindMinutes: val)),
                ),
              ],
            ),
          ],
        ),
        SettingsSection(
          title: l10n.liveTvPlaylists,
          description: l10n.liveTvPlaylistsDesc,
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
