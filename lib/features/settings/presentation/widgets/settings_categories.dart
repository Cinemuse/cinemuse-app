import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_toggle.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_input.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/stremio_addon_settings.dart';
import 'package:cinemuse_app/features/settings/domain/subtitle_style.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/subtitle_appearance_form.dart';

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
              onSave: (val) => settingsNotifier.updateSettings({'displayName': val}),
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
    final l10n = AppLocalizations.of(context)!;
    final userSettings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Column(
      children: [
        SettingsSection(
          title: l10n.settingsCustomization,
          description: l10n.settingsCustomizationDesc,
          children: [
            // Interface Language
            SettingsCard(
              children: [
                SettingsTile(
                  label: l10n.settingsAppLanguage,
                  description: l10n.settingsAppLanguageDesc,
                  icon: Icons.language,
                   trailing: buildSmallDropdown<String>(
                    value: userSettings.appLanguage,
                    items: [
                      DropdownMenuItem(value: 'en', child: Text(l10n.settingsEnglish)),
                      DropdownMenuItem(value: 'it', child: Text(l10n.settingsItalian)),
                    ],
                    onChanged: (lang) => settingsNotifier.updateSettings({'appLanguage': lang}),
                  ),
                ),
              ],
            ),

            // Media Preferences
            SettingsCard(
              children: [
                SettingsTile(
                  label: l10n.settingsAudioLanguage,
                  description: l10n.settingsAudioLanguageDesc,
                  icon: Icons.audiotrack,
                  trailing: buildSmallDropdown<String>(
                    value: userSettings.playerLanguage,
                    items: [
                      DropdownMenuItem(value: 'en', child: Text(l10n.settingsEnglish)),
                      DropdownMenuItem(value: 'it', child: Text(l10n.settingsItalian)),
                    ],
                    onChanged: (lang) => settingsNotifier.updateSettings({'playerLanguage': lang}),
                  ),
                ),
                SettingsTile(
                  label: l10n.settingsShowSubtitles,
                  description: l10n.settingsShowSubtitles,
                  icon: Icons.subtitles,
                  trailing: SettingToggle(
                    value: userSettings.showSubtitles,
                    onChanged: (val) => settingsNotifier.updateSettings({'showSubtitles': val}),
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
                        DropdownMenuItem(value: 'en', child: Text(l10n.settingsEnglish)),
                        DropdownMenuItem(value: 'it', child: Text(l10n.settingsItalian)),
                      ],
                      onChanged: (lang) => settingsNotifier.updateSettings({'subtitleLanguage': lang}),
                    ),
                  ),
                SettingsTile(
                  label: l10n.settingsSplitAnimePreferences,
                  description: l10n.settingsSplitAnimePreferencesDesc,
                  icon: Icons.auto_awesome,
                  showDivider: userSettings.splitAnimePreferences,
                  trailing: SettingToggle(
                    value: userSettings.splitAnimePreferences,
                    onChanged: (val) => settingsNotifier.updateSettings({'splitAnimePreferences': val}),
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
                            DropdownMenuItem(value: 'ja', child: Text(l10n.settingsOriginal)),
                            DropdownMenuItem(value: 'en', child: Text(l10n.settingsEnglish)),
                            DropdownMenuItem(value: 'it', child: Text(l10n.settingsItalian)),
                          ],
                          onChanged: (lang) => settingsNotifier.updateSettings({'animeAudioLanguage': lang}),
                        ),
                      ),
                      SettingsTile(
                        label: l10n.settingsAnimeShowSubtitles,
                        description: l10n.settingsAnimeShowSubtitlesDesc,
                        icon: Icons.subtitles,
                        trailing: SettingToggle(
                          value: userSettings.animeShowSubtitles,
                          onChanged: (val) => settingsNotifier.updateSettings({'animeShowSubtitles': val}),
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
                              DropdownMenuItem(value: 'en', child: Text(l10n.settingsEnglish)),
                              DropdownMenuItem(value: 'it', child: Text(l10n.settingsItalian)),
                            ],
                            onChanged: (lang) => settingsNotifier.updateSettings({'animeSubtitleLanguage': lang}),
                          ),
                        ),
                    ],
                  ),
                ],
              ),

            // Region & Other
            SettingsSection(
              title: l10n.settingsOther,
              children: [
                SettingsCard(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.settingsLiveTvRegion,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 12),
                          SettingsRegionSelector(
                            selectedRegion: userSettings.liveTvRegion,
                            onChanged: (region) => settingsNotifier.updateSettings({'liveTvRegion': region}),
                          ),
                        ],
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
  // Removed _buildMediaGroup as it's replaced by SettingsDropdown
}

Widget buildSmallDropdown<T>({
  required T value,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?> onChanged,
}) {
  return Container(
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
        items: items,
        onChanged: onChanged,
        dropdownColor: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        isDense: true, // Crucial to remove internal padding
        alignment: Alignment.center,
        underline: const SizedBox.shrink(),
        icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.textMuted, size: 18),
        style: const TextStyle(
          color: Colors.white, 
          fontSize: 14, 
          fontWeight: FontWeight.w600, // Make text a bit bolder
        ),
      ),
    ),
  );
}

class LiveTvSettings extends ConsumerWidget {
  const LiveTvSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final userSettings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return SettingsSection(
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
                onChanged: (val) => settingsNotifier.updateSettings({'liveTvBufferSize': val}),
              ),
            ),
            SettingsTile(
              label: l10n.settingsLiveTvDiskCache,
              description: l10n.settingsLiveTvDiskCacheDesc,
              icon: Icons.save,
              showDivider: false,
              trailing: SettingToggle(
                value: userSettings.enableLiveTvDiskCache,
                onChanged: (val) => settingsNotifier.updateSettings({'enableLiveTvDiskCache': val}),
              ),
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
      children: const [
        StremioAddonSettings(),
      ],
    );
  }
}


class ImportSettings extends StatelessWidget {
  const ImportSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SettingsSection(
      title: l10n.settingsImport,
      description: l10n.settingsImportDesc,
      children: [
        const SettingsCard(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: double.infinity),
            Icon(Icons.cloud_upload_outlined, size: 48, color: AppTheme.textMuted),
            SizedBox(height: 16),
            Text(
              "No services available for import",
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ],
        ),
      ],
    );
  }
}

class SubtitleAppearanceSettings extends ConsumerWidget {
  const SubtitleAppearanceSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final userSettings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return SettingsSection(
      title: l10n.playerSubtitleAppearance,
      children: [
        SettingsCard(
          children: [
            SubtitleAppearanceForm(
              style: SubtitleStyle(
                fontSize: userSettings.subtitleFontSize,
                color: SubtitleStyle.hexToColor(userSettings.subtitleColor),
                backgroundColor: SubtitleStyle.hexToColor(userSettings.subtitleBackgroundColor),
                verticalPosition: userSettings.subtitleVerticalPosition,
              ),
              onChanged: (newStyle) {
                settingsNotifier.updateSettings({
                  'subtitleFontSize': newStyle.fontSize,
                  'subtitleColor': SubtitleStyle.colorToHex(newStyle.color),
                  'subtitleBackgroundColor': SubtitleStyle.colorToHex(newStyle.backgroundColor),
                  'subtitleVerticalPosition': newStyle.verticalPosition,
                });
              },
            ),
          ],
        ),
      ],
    );
  }
}
