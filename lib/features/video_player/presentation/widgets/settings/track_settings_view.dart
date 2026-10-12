import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/application/language_mapper.dart';
import 'package:cinemuse_app/features/video_player/application/managers/track_manager.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/streaming/subtitles/subtitle_service.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/settings/external_subtitles_section.dart';
import 'settings_widgets.dart';

class TrackSettingsView extends ConsumerWidget {
  final CinemaPlayerState state;
  final PlayerParams params;
  final bool isSubtitle;
  final VoidCallback onBack;

  const TrackSettingsView({
    super.key,
    required this.state,
    required this.params,
    required this.isSubtitle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentState =
        ref.watch(playerControllerProvider(params)).value ?? state;
    final player = currentState.controller.player;
    final l10n = AppLocalizations.of(context)!;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final tracks = isSubtitle
        ? player.state.tracks.subtitle
        : player.state.tracks.audio;
    final selectedTrack = isSubtitle
        ? (currentState.activeSubtitleTrack ?? player.state.track.subtitle)
        : (currentState.activeAudioTrack ?? player.state.track.audio);

    final pref = ref.watch(settingsProvider);
    final prefLang = (currentState.isAnime && pref.splitAnimePreferences)
        ? (isSubtitle ? pref.animeSubtitleLanguage : pref.animeAudioLanguage)
              .toLowerCase()
        : (isSubtitle ? pref.subtitleLanguage : pref.playerLanguage)
              .toLowerCase();

    final regularTracks = tracks
        .where((t) => t.id != 'no' && t.id != 'auto')
        .toList();

    // Include on-demand stream subtitles (e.g. from VixSrc) among internal tracks
    final allInternalTracks = <dynamic>[...regularTracks];
    if (isSubtitle) {
      final onDemandList =
          currentState
                  .currentStream
                  ?.candidate
                  .metadata
                  ?.custom?['onDemandSubtitles']
              as List<dynamic>?;
      if (onDemandList != null) {
        for (final item in onDemandList) {
          if (item is Map) {
            final uri = item['uri'] as String?;
            final name = item['name'] as String?;
            final lang = item['language'] as String?;
            if (uri != null && uri.isNotEmpty) {
              final isAlreadyProbed = regularTracks.any(
                (t) =>
                    (t.title != null && t.title == name) ||
                    (t.language != null && t.language == lang),
              );
              if (!isAlreadyProbed) {
                allInternalTracks.add(
                  SubtitleTrack.uri(uri, title: name, language: lang),
                );
              }
            }
          }
        }
      }
    }

    final noTrack =
        tracks.where((t) => t.id == 'no').firstOrNull ??
        (isSubtitle ? SubtitleTrack.no() : AudioTrack.no());
    final externalSubsAsync = isSubtitle
        ? ref.watch(externalSubtitlesProvider(params))
        : null;

    return Column(
      children: [
        SubViewHeader(
          title: isSubtitle
              ? l10n.playerSelectSubtitle
              : l10n.playerSelectAudio,
          onBack: onBack,
          compact: isLandscape,
        ),
        Flexible(
          fit: FlexFit.loose,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: isLandscape ? 4 : 12),
                _buildDisableTrackTile(
                  ref,
                  player,
                  noTrack,
                  selectedTrack,
                  l10n,
                  autofocus: selectedTrack.id == 'no',
                ),
                if (allInternalTracks.isNotEmpty || isSubtitle)
                  const Divider(
                    color: AppTheme.borderSubtle,
                    height: 32,
                    indent: 8,
                    endIndent: 8,
                  ),
                if (allInternalTracks.isNotEmpty)
                  _buildInternalTracks(
                    ref,
                    player,
                    allInternalTracks,
                    selectedTrack,
                    prefLang,
                    l10n,
                    hasSelectionPrior: selectedTrack.id == 'no',
                  ),
                if (isSubtitle &&
                    ref.read(subtitleServiceProvider).hasActiveProviders) ...[
                  if (allInternalTracks.isNotEmpty)
                    const Divider(
                      color: AppTheme.borderSubtle,
                      height: 32,
                      indent: 8,
                      endIndent: 8,
                    ),
                  ExternalSubtitlesSection(
                    player: player,
                    externalSubsAsync: externalSubsAsync!,
                    isLandscape: isLandscape,
                    onBack: onBack,
                    params: params,
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Section builders
  // ---------------------------------------------------------------------------

  /// Builds the "Off / Disable" or "No Audio / Mute" tile.
  Widget _buildDisableTrackTile(
    WidgetRef ref,
    Player player,
    dynamic noTrack,
    dynamic selectedTrack,
    AppLocalizations l10n, {
    bool autofocus = false,
  }) {
    final isSelected = selectedTrack.id == 'no';
    return TrackTile(
      player: player,
      track: noTrack,
      isSelected: isSelected,
      isSubtitle: isSubtitle,
      customTitle: isSubtitle ? l10n.playerTrackOff : l10n.playerTrackNoAudio,
      color: AppTheme.textMuted,
      onBack: onBack,
      onSelected: () => _notifyManualSelection(ref),
      autofocus: autofocus || isSelected,
    );
  }

  /// Builds the "INTERNAL TRACKS" section header and track list.
  Widget _buildInternalTracks(
    WidgetRef ref,
    Player player,
    List<dynamic> tracks,
    dynamic selectedTrack,
    String prefLang,
    AppLocalizations l10n, {
    bool hasSelectionPrior = false,
  }) {
    final internalTracksHeader = isSubtitle
        ? l10n.playerInternalTracks
        : l10n.playerAudioTracks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(internalTracksHeader),
        Builder(
          builder: (context) {
            bool foundAutoMatch = false;
            final hasMatchInList = tracks.any(
              (track) => _isSameTrack(selectedTrack, track),
            );

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: tracks.asMap().entries.map((entry) {
                final index = entry.key;
                final track = entry.value;
                bool isSelected = _isSameTrack(selectedTrack, track);

                if (!isSelected &&
                    selectedTrack.id == 'auto' &&
                    !foundAutoMatch &&
                    LanguageMapper.isMatch(track, prefLang)) {
                  isSelected = true;
                  foundAutoMatch = true;
                }

                final shouldAutofocus =
                    isSelected ||
                    (!hasSelectionPrior && !hasMatchInList && index == 0);

                return TrackTile(
                  player: player,
                  track: track,
                  isSelected: isSelected,
                  isSubtitle: isSubtitle,
                  onBack: onBack,
                  onSelected: () => _notifyManualSelection(ref),
                  autofocus: shouldAutofocus,
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Widget _sectionHeader(String label) => Padding(
    padding: const EdgeInsets.only(left: 8, bottom: 8),
    child: Text(
      label,
      style: const TextStyle(
        color: AppTheme.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
      ),
    ),
  );

  void _notifyManualSelection(WidgetRef ref) => ref
      .read(playerControllerProvider(params).notifier)
      .setManualTrackSelection();
}

/// By id: two tracks may share a title (e.g. two "English" subtitles, full
/// and SDH), and both looked selected (REV-169). The title counts only for
/// on-demand subtitle entries, whose id is their URI.
bool _isSameTrack(dynamic selected, dynamic track) =>
    selected.id == track.id ||
    (track is SubtitleTrack &&
        track.uri &&
        track.title != null &&
        selected.title == track.title);
