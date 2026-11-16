import 'package:cinemuse_app/core/services/system/phone_orientation.dart';
import 'package:cinemuse_app/core/utils/platform_info.dart';
import 'package:cinemuse_app/features/settings/application/local_settings_service.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/application/watch_region_providers.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/save_settings.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_choice.dart';
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
    final undoTime = ref.watch(localSettingsProvider.select((s) => s.undoTime));
    final screenPercent = ref.watch(
      localSettingsProvider.select((s) => s.screenPercent),
    );
    final startFullScreen = ref.watch(
      localSettingsProvider.select((s) => s.startFullScreen),
    );
    final isDesktop = PlatformInfo.isDesktop;
    // A phone's own text size does Screen size's job.
    final isPhone = PhoneOrientation.isPhone;

    return SettingsCard(
      children: [
        SettingsChoiceTile<String>(
          label: l10n.settingsAppLanguage,
          description: l10n.settingsAppLanguageDesc,
          icon: Icons.language,
          value: appLanguage,
          choices: settingsLanguageChoices(l10n),
          onChanged: (lang) => save((s) => s.copyWith(appLanguage: lang)),
        ),
        WatchRegionTile(
          value: watchRegion,
          onChanged: (code) => save((s) => s.copyWith(watchRegion: code)),
        ),
        SettingsChoiceTile<Duration>(
          label: l10n.settingsUndoTime,
          description: l10n.settingsUndoTimeDesc,
          icon: Icons.undo,
          showDivider: !isPhone,
          value: undoTime,
          choices: [
            for (final seconds in _undoSeconds)
              SettingsChoice(
                Duration(seconds: seconds),
                seconds == 0
                    ? l10n.settingsUndoTimeOff
                    : l10n.settingsUndoTimeSeconds(seconds),
              ),
          ],
          onChanged: (time) =>
              ref.read(localSettingsProvider.notifier).updateUndoTime(time),
        ),
        if (!isPhone)
          SettingsChoiceTile<int>(
            label: l10n.settingsScreenSize,
            description: l10n.settingsScreenSizeDesc,
            icon: Icons.format_size,
            showDivider: isDesktop,
            value: screenPercent,
            choices: [
              for (final percent in LocalSettings.screenPercents)
                SettingsChoice(percent, '$percent%'),
            ],
            onChanged: (percent) => ref
                .read(localSettingsProvider.notifier)
                .updateScreenPercent(percent),
          ),
        if (isDesktop)
          SettingsToggleTile(
            label: l10n.settingsStartFullScreen,
            description: l10n.settingsStartFullScreenDesc,
            icon: Icons.fullscreen,
            showDivider: false,
            value: startFullScreen,
            onChanged: (on) => ref
                .read(localSettingsProvider.notifier)
                .updateStartFullScreen(on),
          ),
      ],
    );
  }

  /// The Undo time choices; 0 is Off.
  static const _undoSeconds = [0, 4, 6, 8, 10, 15];
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
        SettingsChoiceTile<String>(
          label: l10n.settingsAudioLanguage,
          description: l10n.settingsAudioLanguageDesc,
          icon: Icons.audiotrack,
          value: userSettings.playerLanguage,
          choices: settingsLanguageChoices(l10n),
          onChanged: (lang) => save((s) => s.copyWith(playerLanguage: lang)),
        ),
        SettingsToggleTile(
          label: l10n.settingsShowSubtitles,
          description: l10n.settingsShowSubtitlesDesc,
          icon: Icons.subtitles,
          value: userSettings.showSubtitles,
          onChanged: (val) => save((s) => s.copyWith(showSubtitles: val)),
        ),
        if (userSettings.showSubtitles)
          SettingsChoiceTile<String>(
            label: l10n.settingsSubtitleLanguage,
            description: l10n.settingsSubtitleLanguageDesc,
            icon: Icons.translate,
            value: userSettings.subtitleLanguage,
            choices: settingsLanguageChoices(l10n),
            onChanged: (lang) =>
                save((s) => s.copyWith(subtitleLanguage: lang)),
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
        SettingsChoiceTile<VideoResolution>(
          label: l10n.settingsMaxResolution,
          description: l10n.settingsMaxResolutionDesc,
          icon: Icons.hd,
          showDivider: false,
          value: maxResolution,
          choices: [
            for (final res in VideoResolution.values)
              SettingsChoice(res, _resolutionLabel(res, l10n)),
          ],
          onChanged: (res) =>
              ref.read(localSettingsProvider.notifier).updateMaxResolution(res),
        ),
      ],
    );
  }

  static String _resolutionLabel(VideoResolution res, AppLocalizations l10n) =>
      switch (res) {
        VideoResolution.r2160p => '4K',
        VideoResolution.r1440p => '1440p',
        VideoResolution.r1080p => '1080p',
        VideoResolution.r720p => '720p',
        VideoResolution.r480p => '480p',
        VideoResolution.unknown => l10n.settingsResolutionAny,
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
            SettingsChoiceTile<String>(
              label: l10n.settingsAnimeAudioLanguage,
              description: l10n.settingsAnimeAudioLanguageDesc,
              icon: Icons.audiotrack,
              value: userSettings.animeAudioLanguage,
              choices: settingsLanguageChoices(l10n, hasOriginal: true),
              onChanged: (lang) =>
                  save((s) => s.copyWith(animeAudioLanguage: lang)),
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
              SettingsChoiceTile<String>(
                label: l10n.settingsAnimeSubtitleLanguage,
                description: l10n.settingsAnimeSubtitleLanguageDesc,
                icon: Icons.translate,
                showDivider: false,
                value: userSettings.animeSubtitleLanguage,
                choices: settingsLanguageChoices(l10n),
                onChanged: (lang) =>
                    save((s) => s.copyWith(animeSubtitleLanguage: lang)),
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
