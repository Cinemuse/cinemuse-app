import 'package:cinemuse_app/features/settings/application/local_settings_service.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/application/watch_region_providers.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/save_settings.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_toggle.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/subtitle_appearance_form.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/watch_region_dropdown.dart';
import 'package:cinemuse_app/features/streaming/models/stream_metadata.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Customization category: app language and streaming country,
/// playback, anime, subtitles.
class CustomizationSettings extends ConsumerWidget {
  const CustomizationSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isAnimeSplit = ref.watch(
      settingsProvider.select((s) => s.splitAnimePreferences),
    );

    return SettingsSection(
      title: l10n.settingsCustomization,
      description: l10n.settingsCustomizationDesc,
      children: [
        const _AppLanguageCard(),
        const _PlaybackCard(),
        if (isAnimeSplit) const _AnimeSection(),
        const _SubtitleAppearanceSection(),
      ],
    );
  }
}

class _AppLanguageCard extends ConsumerWidget {
  const _AppLanguageCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final save = settingsSaver(context, ref);
    final l10n = AppLocalizations.of(context)!;
    final appLanguage = ref.watch(
      settingsProvider.select((s) => s.appLanguage),
    );
    final watchRegion = ref.watch(watchRegionProvider);

    return SettingsCard(
      children: [
        SettingsTile(
          label: l10n.settingsAppLanguage,
          description: l10n.settingsAppLanguageDesc,
          icon: Icons.language,
          trailing: SettingsLanguageDropdown(
            value: appLanguage,
            onChanged: (lang) => save((s) => s.copyWith(appLanguage: lang)),
          ),
        ),
        SettingsTile(
          label: l10n.settingsWatchRegion,
          description: l10n.settingsWatchRegionDesc,
          icon: Icons.public,
          showDivider: false,
          trailing: WatchRegionDropdown(
            value: watchRegion,
            onChanged: (code) => save((s) => s.copyWith(watchRegion: code)),
          ),
        ),
      ],
    );
  }
}

class _PlaybackCard extends ConsumerWidget {
  const _PlaybackCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final save = settingsSaver(context, ref);
    final l10n = AppLocalizations.of(context)!;
    final userSettings = ref.watch(settingsProvider);
    final maxResolution = ref.watch(
      localSettingsProvider.select((s) => s.maxResolution),
    );

    return SettingsCard(
      children: [
        SettingsTile(
          label: l10n.settingsAudioLanguage,
          description: l10n.settingsAudioLanguageDesc,
          icon: Icons.audiotrack,
          trailing: SettingsLanguageDropdown(
            value: userSettings.playerLanguage,
            onChanged: (lang) => save((s) => s.copyWith(playerLanguage: lang)),
          ),
        ),
        SettingsToggleTile(
          label: l10n.settingsShowSubtitles,
          description: l10n.settingsShowSubtitlesDesc,
          icon: Icons.subtitles,
          value: userSettings.showSubtitles,
          onChanged: (val) => save((s) => s.copyWith(showSubtitles: val)),
        ),
        if (userSettings.showSubtitles)
          SettingsTile(
            label: l10n.settingsSubtitleLanguage,
            description: l10n.settingsSubtitleLanguageDesc,
            icon: Icons.translate,
            trailing: SettingsLanguageDropdown(
              value: userSettings.subtitleLanguage,
              onChanged: (lang) =>
                  save((s) => s.copyWith(subtitleLanguage: lang)),
            ),
          ),
        SettingsToggleTile(
          label: l10n.settingsSplitAnimePreferences,
          description: l10n.settingsSplitAnimePreferencesDesc,
          icon: Icons.auto_awesome,
          showDivider: userSettings.splitAnimePreferences,
          value: userSettings.splitAnimePreferences,
          onChanged: (val) =>
              save((s) => s.copyWith(splitAnimePreferences: val)),
        ),
        SettingsTile(
          label: l10n.settingsMaxResolution,
          description: l10n.settingsMaxResolutionDesc,
          icon: Icons.hd,
          showDivider: false,
          trailing: SettingsSmallDropdown<VideoResolution>(
            value: maxResolution,
            items: [
              for (final res in VideoResolution.values)
                DropdownMenuItem(
                  value: res,
                  child: Text(_resolutionLabel(res)),
                ),
            ],
            onChanged: (res) {
              if (res != null) {
                ref
                    .read(localSettingsProvider.notifier)
                    .updateMaxResolution(res);
              }
            },
          ),
        ),
      ],
    );
  }

  static String _resolutionLabel(VideoResolution res) => switch (res) {
    VideoResolution.r2160p => '4K',
    VideoResolution.r1440p => '1440p',
    VideoResolution.r1080p => '1080p',
    VideoResolution.r720p => '720p',
    VideoResolution.r480p => '480p',
    VideoResolution.unknown => 'Any',
  };
}

class _AnimeSection extends ConsumerWidget {
  const _AnimeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final save = settingsSaver(context, ref);
    final l10n = AppLocalizations.of(context)!;
    final userSettings = ref.watch(settingsProvider);

    return SettingsSection(
      title: "ANIME",
      children: [
        SettingsCard(
          children: [
            SettingsTile(
              label: l10n.settingsAnimeAudioLanguage,
              description: l10n.settingsAnimeAudioLanguageDesc,
              icon: Icons.audiotrack,
              trailing: SettingsLanguageDropdown(
                value: userSettings.animeAudioLanguage,
                hasOriginal: true,
                onChanged: (lang) =>
                    save((s) => s.copyWith(animeAudioLanguage: lang)),
              ),
            ),
            SettingsToggleTile(
              label: l10n.settingsAnimeShowSubtitles,
              description: l10n.settingsAnimeShowSubtitlesDesc,
              icon: Icons.subtitles,
              value: userSettings.animeShowSubtitles,
              onChanged: (val) =>
                  save((s) => s.copyWith(animeShowSubtitles: val)),
            ),
            if (userSettings.animeShowSubtitles)
              SettingsTile(
                label: l10n.settingsAnimeSubtitleLanguage,
                description: l10n.settingsAnimeSubtitleLanguageDesc,
                icon: Icons.translate,
                showDivider: false,
                trailing: SettingsLanguageDropdown(
                  value: userSettings.animeSubtitleLanguage,
                  onChanged: (lang) =>
                      save((s) => s.copyWith(animeSubtitleLanguage: lang)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SubtitleAppearanceSection extends ConsumerWidget {
  const _SubtitleAppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final subtitleStyle = ref.watch(
      localSettingsProvider.select((s) => s.subtitleStyle),
    );
    final localNotifier = ref.read(localSettingsProvider.notifier);

    return SettingsSection(
      title: l10n.playerSubtitleAppearance,
      children: [
        SettingsCard(
          children: [
            SubtitleAppearanceForm(
              style: subtitleStyle,
              onChanged: localNotifier.previewSubtitleStyle,
              onChangeEnd: localNotifier.updateSubtitleStyle,
            ),
          ],
        ),
      ],
    );
  }
}
