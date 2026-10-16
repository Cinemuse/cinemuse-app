import 'package:flutter/material.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';
import 'package:cinemuse_app/shared/widgets/menu/menu_focus_ring.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_toggle.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_input.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/save_settings.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/application/local_settings_service.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/addon_settings.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/subtitle_appearance_form.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/playlist_management_sheet.dart';
import 'package:cinemuse_app/features/streaming/models/stream_metadata.dart';

class IdentitySettings extends ConsumerWidget {
  const IdentitySettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final userSettings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return SettingsSection(
      title: l10n.settingsIdentity,
      description: l10n.settingsIdentityDesc,
      children: [
        SettingsCard(
          children: [
            SettingInput(
              label: l10n.settingsDisplayName,
              description: l10n.settingsDisplayNameDesc,
              value: userSettings.displayName,
              placeholder: l10n.settingsEnterName,
              // SettingInput shows its own error, so it needs the throw.
              onSave: (val) => settingsNotifier.updateSettings(
                (s) => s.copyWith(displayName: val),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class CustomizationSettings extends ConsumerWidget {
  const CustomizationSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final save = settingsSaver(context, ref);
    final l10n = AppLocalizations.of(context)!;
    final userSettings = ref.watch(settingsProvider);
    final localSettings = ref.watch(localSettingsProvider);
    final localNotifier = ref.read(localSettingsProvider.notifier);

    return Column(
      children: [
        SettingsSection(
          title: l10n.settingsCustomization,
          description: l10n.settingsCustomizationDesc,
          children: [
            SettingsCard(
              children: [
                SettingsTile(
                  label: l10n.settingsAppLanguage,
                  description: l10n.settingsAppLanguageDesc,
                  icon: Icons.language,
                  showDivider: false,
                  trailing: buildSmallDropdown<String>(
                    value: userSettings.appLanguage,
                    items: [
                      DropdownMenuItem(
                        value: 'en',
                        child: Text(l10n.settingsEnglish),
                      ),
                      DropdownMenuItem(
                        value: 'it',
                        child: Text(l10n.settingsItalian),
                      ),
                    ],
                    onChanged: (lang) =>
                        save((s) => s.copyWith(appLanguage: lang)),
                  ),
                ),
              ],
            ),

            SettingsCard(
              children: [
                SettingsTile(
                  label: l10n.settingsAudioLanguage,
                  description: l10n.settingsAudioLanguageDesc,
                  icon: Icons.audiotrack,
                  trailing: buildSmallDropdown<String>(
                    value: userSettings.playerLanguage,
                    items: [
                      DropdownMenuItem(
                        value: 'en',
                        child: Text(l10n.settingsEnglish),
                      ),
                      DropdownMenuItem(
                        value: 'it',
                        child: Text(l10n.settingsItalian),
                      ),
                    ],
                    onChanged: (lang) =>
                        save((s) => s.copyWith(playerLanguage: lang)),
                  ),
                ),
                SettingsTile(
                  label: l10n.settingsShowSubtitles,
                  description: l10n.settingsShowSubtitlesDesc,
                  icon: Icons.subtitles,
                  trailing: SettingToggle(
                    value: userSettings.showSubtitles,
                    onChanged: (val) =>
                        save((s) => s.copyWith(showSubtitles: val)),
                  ),
                ),
                if (userSettings.showSubtitles)
                  SettingsTile(
                    label: l10n.settingsSubtitleLanguage,
                    description: l10n.settingsSubtitleLanguageDesc,
                    icon: Icons.translate,
                    trailing: buildSmallDropdown<String>(
                      value: userSettings.subtitleLanguage,
                      items: [
                        DropdownMenuItem(
                          value: 'en',
                          child: Text(l10n.settingsEnglish),
                        ),
                        DropdownMenuItem(
                          value: 'it',
                          child: Text(l10n.settingsItalian),
                        ),
                      ],
                      onChanged: (lang) =>
                          save((s) => s.copyWith(subtitleLanguage: lang)),
                    ),
                  ),
                SettingsTile(
                  label: l10n.settingsSplitAnimePreferences,
                  description: l10n.settingsSplitAnimePreferencesDesc,
                  icon: Icons.auto_awesome,
                  showDivider: userSettings.splitAnimePreferences,
                  trailing: SettingToggle(
                    value: userSettings.splitAnimePreferences,
                    onChanged: (val) =>
                        save((s) => s.copyWith(splitAnimePreferences: val)),
                  ),
                ),
                SettingsTile(
                  label: l10n.settingsMaxResolution,
                  description: l10n.settingsMaxResolutionDesc,
                  icon: Icons.hd,
                  showDivider: false,
                  trailing: buildSmallDropdown<VideoResolution>(
                    value: localSettings.maxResolution,
                    items: VideoResolution.values.map((res) {
                      String text;
                      switch (res) {
                        case VideoResolution.r2160p:
                          text = '4K';
                          break;
                        case VideoResolution.r1440p:
                          text = '1440p';
                          break;
                        case VideoResolution.r1080p:
                          text = '1080p';
                          break;
                        case VideoResolution.r720p:
                          text = '720p';
                          break;
                        case VideoResolution.r480p:
                          text = '480p';
                          break;
                        case VideoResolution.unknown:
                          text = 'Any';
                          break;
                      }
                      return DropdownMenuItem(value: res, child: Text(text));
                    }).toList(),
                    onChanged: (res) {
                      if (res != null) {
                        localNotifier.updateMaxResolution(res);
                      }
                    },
                  ),
                ),
              ],
            ),

            if (userSettings.splitAnimePreferences)
              SettingsSection(
                title: "ANIME",
                children: [
                  SettingsCard(
                    children: [
                      SettingsTile(
                        label: l10n.settingsAnimeAudioLanguage,
                        description: l10n.settingsAnimeAudioLanguageDesc,
                        icon: Icons.audiotrack,
                        trailing: buildSmallDropdown<String>(
                          value: userSettings.animeAudioLanguage,
                          items: [
                            DropdownMenuItem(
                              value: 'ja',
                              child: Text(l10n.settingsOriginal),
                            ),
                            DropdownMenuItem(
                              value: 'en',
                              child: Text(l10n.settingsEnglish),
                            ),
                            DropdownMenuItem(
                              value: 'it',
                              child: Text(l10n.settingsItalian),
                            ),
                          ],
                          onChanged: (lang) =>
                              save((s) => s.copyWith(animeAudioLanguage: lang)),
                        ),
                      ),
                      SettingsTile(
                        label: l10n.settingsAnimeShowSubtitles,
                        description: l10n.settingsAnimeShowSubtitlesDesc,
                        icon: Icons.subtitles,
                        trailing: SettingToggle(
                          value: userSettings.animeShowSubtitles,
                          onChanged: (val) =>
                              save((s) => s.copyWith(animeShowSubtitles: val)),
                        ),
                      ),
                      if (userSettings.animeShowSubtitles)
                        SettingsTile(
                          label: l10n.settingsAnimeSubtitleLanguage,
                          description: l10n.settingsAnimeSubtitleLanguageDesc,
                          icon: Icons.translate,
                          showDivider: false,
                          trailing: buildSmallDropdown<String>(
                            value: userSettings.animeSubtitleLanguage,
                            items: [
                              DropdownMenuItem(
                                value: 'en',
                                child: Text(l10n.settingsEnglish),
                              ),
                              DropdownMenuItem(
                                value: 'it',
                                child: Text(l10n.settingsItalian),
                              ),
                            ],
                            onChanged: (lang) => save(
                              (s) => s.copyWith(animeSubtitleLanguage: lang),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),

            const SubtitleAppearanceSettings(),
          ],
        ),
      ],
    );
  }
}

Widget buildSmallDropdown<T>({
  required T value,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?> onChanged,
}) {
  return FocusRingFollower(
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 38, // Slightly more height for better text centering
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
          isDense: true, // Crucial to remove internal padding
          alignment: Alignment.center,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppTheme.textMuted,
            size: 18,
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600, // Make text a bit bolder
          ),
        ),
      ),
    ),
  );
}

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
                  trailing: buildSmallDropdown<int>(
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
                SettingsTile(
                  label: l10n.settingsLiveTvDiskCache,
                  description: l10n.settingsLiveTvDiskCacheDesc,
                  icon: Icons.save,
                  showDivider: false,
                  trailing: SettingToggle(
                    value: userSettings.enableLiveTvDiskCache,
                    onChanged: (val) =>
                        save((s) => s.copyWith(enableLiveTvDiskCache: val)),
                  ),
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

class IntegrationsSettings extends ConsumerWidget {
  const IntegrationsSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsSection(
      title: l10n.settingsIntegrations,
      description: l10n.settingsIntegrationsDesc,
      children: const [AddonSettings()],
    );
  }
}

class SubtitleAppearanceSettings extends ConsumerWidget {
  const SubtitleAppearanceSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final localSettings = ref.watch(localSettingsProvider);
    final localNotifier = ref.read(localSettingsProvider.notifier);

    return SettingsSection(
      title: l10n.playerSubtitleAppearance,
      children: [
        SettingsCard(
          children: [
            SubtitleAppearanceForm(
              style: localSettings.subtitleStyle,
              onChanged: localNotifier.previewSubtitleStyle,
              onChangeEnd: localNotifier.updateSubtitleStyle,
            ),
          ],
        ),
      ],
    );
  }
}
