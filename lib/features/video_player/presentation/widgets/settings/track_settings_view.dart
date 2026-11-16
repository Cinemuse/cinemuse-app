import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/application/managers/track_manager.dart';
import 'package:cinemuse_app/features/video_player/application/track_choices.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/streaming/subtitles/subtitle_service.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/settings/external_subtitles_section.dart';
import 'pick_track.dart';
import 'settings_headers.dart';
import 'track_tile.dart';

class TrackSettingsView extends ConsumerWidget {
  final CinemaPlayerState state;
  final PlayerParams params;
  final bool isSubtitle;

  const TrackSettingsView({
    super.key,
    required this.state,
    required this.params,
    required this.isSubtitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentState =
        ref.watch(playerControllerProvider(params)).value ?? state;
    final l10n = AppLocalizations.of(context)!;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final language = ref.watch(
      settingsProvider.select(
        (s) => isSubtitle
            ? preferredSubtitleLanguage(s, isAnime: currentState.isAnime)
            : preferredAudioLanguage(s, isAnime: currentState.isAnime),
      ),
    );
    final choices = isSubtitle
        ? TrackChoices.subtitles(
            currentState,
            language,
            flagged: ref.watch(subtitleFlagsProvider(params)),
          )
        : TrackChoices.audio(currentState, language);
    // A YouTube video is no film or episode: there is nothing to search.
    final hasExternalSubtitles =
        isSubtitle &&
        params.type != 'youtube' &&
        ref.watch(subtitleServiceProvider).hasActiveProviders;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: isLandscape ? 4 : 12),
          TrackTile(
            track: choices.offTrack,
            isSelected: choices.isOff,
            customTitle: isSubtitle
                ? l10n.playerTrackOff
                : l10n.playerTrackNoAudio,
            color: AppTheme.textMuted,
            onPick: () => _pick(context, ref, choices.offTrack),
            autofocus: choices.isOff,
          ),
          if (choices.tracks.isNotEmpty || isSubtitle)
            const Divider(
              color: AppTheme.borderSubtle,
              height: 32,
              indent: 8,
              endIndent: 8,
            ),
          if (choices.tracks.isNotEmpty)
            _InternalTracks(
              title: isSubtitle
                  ? l10n.playerInternalTracks
                  : l10n.playerAudioTracks,
              choices: choices,
              fetching: isSubtitle
                  ? ref.watch(fetchingSubtitleProvider(params))
                  : null,
              onPick: (track) => _pick(context, ref, track),
            ),
          if (hasExternalSubtitles) ...[
            if (choices.tracks.isNotEmpty)
              const Divider(
                color: AppTheme.borderSubtle,
                height: 32,
                indent: 8,
                endIndent: 8,
              ),
            ExternalSubtitlesSection(
              externalSubsAsync: ref.watch(externalSubtitlesProvider(params)),
              isLandscape: isLandscape,
              params: params,
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Turns [track] on; the panel stays open, the video shows the result.
  /// A refused track shows the error.
  Future<void> _pick(BuildContext context, WidgetRef ref, Object track) {
    final controller = ref.read(playerControllerProvider(params).notifier);
    return pickTrack(
      context,
      () => controller.selectTrack(track),
      failedMessage: AppLocalizations.of(context)!.playerTrackSwitchFailed,
    );
  }
}

/// The "INTERNAL TRACKS" header and list; focus starts on the track that is
/// on, else on the first one.
class _InternalTracks extends StatelessWidget {
  final String title;
  final TrackChoices choices;

  /// The id of the subtitle being fetched, if any.
  final String? fetching;
  final ValueChanged<Object> onPick;

  const _InternalTracks({
    required this.title,
    required this.choices,
    required this.fetching,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final hasOnInList = choices.tracks.any(choices.isOn);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionTitle(title),
        for (final (index, track) in choices.tracks.indexed)
          TrackTile(
            track: track,
            kind: choices.kindOf(track),
            isSelected: choices.isOn(track),
            isLoading: fetching != null && track.id == fetching,
            onPick: () => onPick(track),
            autofocus:
                choices.isOn(track) ||
                (!choices.isOff && !hasOnInList && index == 0),
          ),
      ],
    );
  }
}
