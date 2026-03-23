import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/application/language_mapper.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
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
    final currentState = ref.watch(playerControllerProvider(params)).value ?? state;
    final player = currentState.controller.player;
    final l10n = AppLocalizations.of(context)!;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final tracks = isSubtitle ? player.state.tracks.subtitle : player.state.tracks.audio;
    final selectedTrack = isSubtitle
        ? (currentState.activeSubtitleTrack ?? player.state.track.subtitle)
        : (currentState.activeAudioTrack ?? player.state.track.audio);

    final pref = ref.watch(settingsProvider);
    final prefLang = (currentState.isAnime && pref.splitAnimePreferences)
        ? (isSubtitle ? pref.animeSubtitleLanguage : pref.animeAudioLanguage).toLowerCase()
        : (isSubtitle ? pref.subtitleLanguage : pref.playerLanguage).toLowerCase();

    final regularTracks = tracks.where((t) => t.id != 'no' && t.id != 'auto').toList();
    final noTrack = tracks.where((t) => t.id == 'no').firstOrNull ?? (isSubtitle ? SubtitleTrack.no() : AudioTrack.no());

    return Column(
      children: [
        SubViewHeader(
          title: isSubtitle ? l10n.playerSelectSubtitle : l10n.playerSelectAudio,
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
                if (regularTracks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        isSubtitle ? "No internal subtitles found" : "No audio tracks found",
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                  )
                else
                  Builder(
                    builder: (context) {
                      bool foundAutoMatch = false;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: regularTracks.map((track) {
                          bool isSelected = selectedTrack.id == track.id;
                          
                          if (!isSelected && selectedTrack.id == 'auto' && !foundAutoMatch && LanguageMapper.isMatch(track, prefLang)) {
                            isSelected = true;
                            foundAutoMatch = true;
                          }

                          return TrackTile(
                            player: player,
                            track: track,
                            isSelected: isSelected,
                            isSubtitle: isSubtitle,
                            onBack: onBack,
                          );
                        }).toList(),
                      );
                    }
                  ),
                const Divider(color: Colors.white10, height: 32, indent: 16, endIndent: 16),
                TrackTile(
                  player: player,
                  track: noTrack,
                  isSelected: selectedTrack.id == 'no',
                  isSubtitle: isSubtitle,
                  customTitle: isSubtitle ? "Off / Disable" : "No Audio / Mute",
                  color: AppTheme.textMuted,
                  onBack: onBack,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
