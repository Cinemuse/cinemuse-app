import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_toggle.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_input.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';

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
        // Language Section
        SettingsCard(
          children: [
            Text(
              l10n.settingsLanguage.toUpperCase(),
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.settingsAppLanguage,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.settingsAppLanguageDesc,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SettingsLanguageButton(
                  label: l10n.settingsEnglish,
                  isSelected: userSettings.appLanguage == 'en',
                  onTap: () => settingsNotifier.updateSettings({'appLanguage': 'en'}),
                ),
                const SizedBox(width: 8),
                SettingsLanguageButton(
                  label: l10n.settingsItalian,
                  isSelected: userSettings.appLanguage == 'it',
                  onTap: () => settingsNotifier.updateSettings({'appLanguage': 'it'}),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(color: Colors.white10),
            const SizedBox(height: 24),
            Text(
              l10n.settingsAudioLanguage,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.settingsAudioLanguageDesc,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SettingsLanguageButton(
                  label: l10n.settingsEnglish,
                  isSelected: userSettings.playerLanguage == 'en',
                  onTap: () => settingsNotifier.updateSettings({'playerLanguage': 'en'}),
                ),
                const SizedBox(width: 8),
                SettingsLanguageButton(
                  label: l10n.settingsItalian,
                  isSelected: userSettings.playerLanguage == 'it',
                  onTap: () => settingsNotifier.updateSettings({'playerLanguage': 'it'}),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(color: Colors.white10),
            const SizedBox(height: 24),
            Text(
              l10n.settingsLiveTvRegion.toUpperCase(),
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.settingsLiveTvRegionDesc,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 16),
            SettingsRegionSelector(
              selectedRegion: userSettings.liveTvRegion,
              onChanged: (region) => settingsNotifier.updateSettings({'liveTvRegion': region}),
            ),
          ],
        ),

        // Other Section
        SettingsCard(
          children: [
            Text(
              l10n.settingsOther.toUpperCase(),
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            SettingToggle(
              label: l10n.settingsSmartSearch,
              description: l10n.settingsSmartSearchDesc,
              value: userSettings.smartSearchFilter,
              onChanged: (val) => settingsNotifier.updateSettings({'smartSearchFilter': val}),
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
    final userSettings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return SettingsSection(
      title: l10n.settingsIntegrations,
      description: l10n.settingsIntegrationsDesc,
      children: [
        SettingsCard(
          children: [
            const Text(
              "REAL-DEBRID",
              style: TextStyle(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            SettingToggle(
              label: l10n.settingsEnableRealDebrid,
              description: l10n.settingsEnableRealDebridDesc,
              value: userSettings.enableRealDebrid,
              onChanged: (val) => settingsNotifier.updateSettings({'enableRealDebrid': val}),
            ),
            SettingInput(
              label: l10n.settingsRealDebridKey,
              value: userSettings.realDebridKey,
              onSave: (val) => settingsNotifier.updateSettings({'realDebridKey': val}),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),
            const Text(
              "MEDIAFUSION",
              style: TextStyle(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            SettingInput(
              label: l10n.settingsMediafusionUrl,
              description: l10n.settingsMediafusionUrlDesc,
              value: userSettings.mediafusionUrl,
              placeholder: l10n.settingsMediafusionHint,
              onSave: (val) => settingsNotifier.updateSettings({'mediafusionUrl': val}),
            ),
          ],
        ),
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
