import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_toggle.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_input.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/stremio_addon_settings.dart';

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

    return SettingsSection(
      title: l10n.settingsCustomization,
      description: l10n.settingsCustomizationDesc,
      children: [
        // Interface Language
        SettingsCard(
          children: [
            SettingsDropdown<String>(
              label: l10n.settingsAppLanguage,
              value: userSettings.appLanguage,
              items: [
                DropdownMenuItem(value: 'en', child: Text(l10n.settingsEnglish)),
                DropdownMenuItem(value: 'it', child: Text(l10n.settingsItalian)),
              ],
              onChanged: (lang) => settingsNotifier.updateSettings({'appLanguage': lang}),
            ),
          ],
        ),

        // Media Preferences
        SettingsCard(
          children: [
            _buildSectionHeader(l10n.settingsPlayer),
            const SizedBox(height: 16),
            
            // General Audio
            SettingsDropdown<String>(
              label: l10n.settingsAudioLanguage,
              value: userSettings.playerLanguage,
              items: [
                DropdownMenuItem(value: 'en', child: Text(l10n.settingsEnglish)),
                DropdownMenuItem(value: 'it', child: Text(l10n.settingsItalian)),
              ],
              onChanged: (lang) => settingsNotifier.updateSettings({'playerLanguage': lang}),
            ),
            
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),

            // General Subtitles
            SettingToggle(
              label: l10n.settingsShowSubtitles,
              value: userSettings.showSubtitles,
              onChanged: (val) => settingsNotifier.updateSettings({'showSubtitles': val}),
            ),
            if (userSettings.showSubtitles) ...[
              const SizedBox(height: 8),
              SettingsDropdown<String>(
                label: l10n.settingsSubtitleLanguage,
                value: userSettings.subtitleLanguage,
                items: [
                  DropdownMenuItem(value: 'en', child: Text(l10n.settingsEnglish)),
                  DropdownMenuItem(value: 'it', child: Text(l10n.settingsItalian)),
                ],
                onChanged: (lang) => settingsNotifier.updateSettings({'subtitleLanguage': lang}),
              ),
            ],

            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),

            // Split Toggle
            SettingToggle(
              label: l10n.settingsSplitAnimePreferences,
              value: userSettings.splitAnimePreferences,
              onChanged: (val) => settingsNotifier.updateSettings({'splitAnimePreferences': val}),
            ),

            if (userSettings.splitAnimePreferences) ...[
              const SizedBox(height: 16),
              const Divider(color: Colors.white10, thickness: 2),
              const SizedBox(height: 16),
              _buildSectionHeader("ANIME"),
              const SizedBox(height: 16),
              
              // Anime Audio
              SettingsDropdown<String>(
                label: l10n.settingsAnimeAudioLanguage,
                value: userSettings.animeAudioLanguage,
                items: [
                  DropdownMenuItem(value: 'ja', child: Text(l10n.settingsOriginal)),
                  DropdownMenuItem(value: 'en', child: Text(l10n.settingsEnglish)),
                  DropdownMenuItem(value: 'it', child: Text(l10n.settingsItalian)),
                ],
                onChanged: (lang) => settingsNotifier.updateSettings({'animeAudioLanguage': lang}),
              ),
              
              const SizedBox(height: 16),
              const Divider(color: Colors.white10),
              const SizedBox(height: 16),

              // Anime Subtitles
              SettingToggle(
                label: l10n.settingsAnimeShowSubtitles,
                value: userSettings.animeShowSubtitles,
                onChanged: (val) => settingsNotifier.updateSettings({'animeShowSubtitles': val}),
              ),
              if (userSettings.animeShowSubtitles) ...[
                const SizedBox(height: 8),
                SettingsDropdown<String>(
                  label: l10n.settingsAnimeSubtitleLanguage,
                  value: userSettings.animeSubtitleLanguage,
                  items: [
                    DropdownMenuItem(value: 'en', child: Text(l10n.settingsEnglish)),
                    DropdownMenuItem(value: 'it', child: Text(l10n.settingsItalian)),
                  ],
                  onChanged: (lang) => settingsNotifier.updateSettings({'animeSubtitleLanguage': lang}),
                ),
              ],
            ],
          ],
        ),

        // Live TV / Other
        SettingsCard(
          children: [
            _buildSectionHeader(l10n.settingsLiveTvRegion),
            const SizedBox(height: 12),
            SettingsRegionSelector(
              selectedRegion: userSettings.liveTvRegion,
              onChanged: (region) => settingsNotifier.updateSettings({'liveTvRegion': region}),
            ),
            const SizedBox(height: 24),
            const Divider(color: Colors.white10),
            const SizedBox(height: 24),
            SettingToggle(
              label: l10n.settingsSmartSearch,
              value: userSettings.smartSearchFilter,
              onChanged: (val) => settingsNotifier.updateSettings({'smartSearchFilter': val}),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: AppTheme.textMuted,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    );
  }

  // Removed _buildMediaGroup as it's replaced by SettingsDropdown
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
