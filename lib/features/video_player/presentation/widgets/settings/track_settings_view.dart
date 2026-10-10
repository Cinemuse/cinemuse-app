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

class TrackSettingsView extends ConsumerStatefulWidget {
  final CinemaPlayerState state;
  final PlayerParams params;
  final bool isSubtitle;
  final VoidCallback onBack;
  final void Function(String)? onNavigate;

  const TrackSettingsView({
    super.key,
    required this.state,
    required this.params,
    required this.isSubtitle,
    required this.onBack,
    this.onNavigate,
  });

  @override
  ConsumerState<TrackSettingsView> createState() => _TrackSettingsViewState();
}

class _TrackSettingsViewState extends ConsumerState<TrackSettingsView> {
  @override
  Widget build(BuildContext context) {
    final currentState =
        ref.watch(playerControllerProvider(widget.params)).value ??
        widget.state;
    final player = currentState.controller.player;
    final l10n = AppLocalizations.of(context)!;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final tracks = widget.isSubtitle
        ? player.state.tracks.subtitle
        : player.state.tracks.audio;
    final selectedTrack = widget.isSubtitle
        ? (currentState.activeSubtitleTrack ?? player.state.track.subtitle)
        : (currentState.activeAudioTrack ?? player.state.track.audio);

    final pref = ref.watch(settingsProvider);
    final prefLang = (currentState.isAnime && pref.splitAnimePreferences)
        ? (widget.isSubtitle
                  ? pref.animeSubtitleLanguage
                  : pref.animeAudioLanguage)
              .toLowerCase()
        : (widget.isSubtitle ? pref.subtitleLanguage : pref.playerLanguage)
              .toLowerCase();

    final regularTracks = tracks
        .where((t) => t.id != 'no' && t.id != 'auto')
        .toList();

    // Include on-demand stream subtitles (e.g. from VixSrc) among internal tracks
    final allInternalTracks = <dynamic>[...regularTracks];
    if (widget.isSubtitle) {
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
        (widget.isSubtitle ? SubtitleTrack.no() : AudioTrack.no());
    final externalSubsAsync = widget.isSubtitle
        ? ref.watch(externalSubtitlesProvider(widget.params))
        : null;

    return Column(
      children: [
        SubViewHeader(
          title: widget.isSubtitle
              ? l10n.playerSelectSubtitle
              : l10n.playerSelectAudio,
          onBack: widget.onBack,
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
                  player,
                  noTrack,
                  selectedTrack,
                  l10n,
                  autofocus: selectedTrack.id == 'no',
                ),
                if (allInternalTracks.isNotEmpty || widget.isSubtitle)
                  const Divider(
                    color: AppTheme.borderSubtle,
                    height: 32,
                    indent: 8,
                    endIndent: 8,
                  ),
                if (allInternalTracks.isNotEmpty)
                  _buildInternalTracks(
                    player,
                    allInternalTracks,
                    selectedTrack,
                    prefLang,
                    l10n,
                    hasSelectionPrior: selectedTrack.id == 'no',
                  ),
                if (widget.isSubtitle &&
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
                    onBack: widget.onBack,
                    params: widget.params,
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
      isSubtitle: widget.isSubtitle,
      customTitle: widget.isSubtitle
          ? l10n.playerTrackOff
          : l10n.playerTrackNoAudio,
      color: AppTheme.textMuted,
      onBack: widget.onBack,
      onSelected: _notifyManualSelection,
      autofocus: autofocus || isSelected,
    );
  }

  /// Builds the "INTERNAL TRACKS" section header and track list.
  Widget _buildInternalTracks(
    Player player,
    List<dynamic> tracks,
    dynamic selectedTrack,
    String prefLang,
    AppLocalizations l10n, {
    bool hasSelectionPrior = false,
  }) {
    final internalTracksHeader = widget.isSubtitle
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
              (track) =>
                  selectedTrack.id == track.id ||
                  (selectedTrack.title != null &&
                      track.title != null &&
                      selectedTrack.title == track.title),
            );

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: tracks.asMap().entries.map((entry) {
                final index = entry.key;
                final track = entry.value;
                bool isSelected =
                    selectedTrack.id == track.id ||
                    (selectedTrack.title != null &&
                        track.title != null &&
                        selectedTrack.title == track.title);

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
                  isSubtitle: widget.isSubtitle,
                  onBack: widget.onBack,
                  onSelected: _notifyManualSelection,
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

  void _notifyManualSelection() => ref
      .read(playerControllerProvider(widget.params).notifier)
      .setManualTrackSelection();
}
