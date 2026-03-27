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
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cinemuse_app/core/services/streaming/subtitles/external_subtitle.dart';
import 'package:cinemuse_app/core/services/streaming/subtitles/subtitle_service.dart';
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
  final Map<String, bool> _expandedLanguages = {};

  @override
  Widget build(BuildContext context) {
    final currentState = ref.watch(playerControllerProvider(widget.params)).value ?? widget.state;
    final player = currentState.controller.player;
    final l10n = AppLocalizations.of(context)!;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final tracks = widget.isSubtitle ? player.state.tracks.subtitle : player.state.tracks.audio;
    final selectedTrack = widget.isSubtitle
        ? (currentState.activeSubtitleTrack ?? player.state.track.subtitle)
        : (currentState.activeAudioTrack ?? player.state.track.audio);

    final pref = ref.watch(settingsProvider);
    final prefLang = (currentState.isAnime && pref.splitAnimePreferences)
        ? (widget.isSubtitle ? pref.animeSubtitleLanguage : pref.animeAudioLanguage).toLowerCase()
        : (widget.isSubtitle ? pref.subtitleLanguage : pref.playerLanguage).toLowerCase();

    final regularTracks = tracks.where((t) => t.id != 'no' && t.id != 'auto').toList();
    final noTrack = tracks.where((t) => t.id == 'no').firstOrNull ?? (widget.isSubtitle ? SubtitleTrack.no() : AudioTrack.no());
    final externalSubsAsync = widget.isSubtitle ? ref.watch(externalSubtitlesProvider(widget.params)) : null;

    return Column(
      children: [
        SubViewHeader(
          title: widget.isSubtitle ? l10n.playerSelectSubtitle : l10n.playerSelectAudio,
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
                _buildDisableTrackTile(player, noTrack, selectedTrack),
                if (regularTracks.isNotEmpty || widget.isSubtitle)
                  const Divider(color: Colors.white10, height: 32, indent: 8, endIndent: 8),
                if (regularTracks.isNotEmpty)
                  _buildInternalTracks(player, regularTracks, selectedTrack, prefLang),
                if (widget.isSubtitle && ref.read(subtitleServiceProvider).hasActiveProviders) ...[
                  if (regularTracks.isNotEmpty)
                    const Divider(color: Colors.white10, height: 32, indent: 8, endIndent: 8),
                  _buildExternalTracks(player, externalSubsAsync!, isLandscape),
                ],
                const SizedBox(height: 24),
                if (widget.isSubtitle && selectedTrack.id != 'no')
                   _SubtitleSyncAdjustment(
                     delaySeconds: currentState.subtitleDelay,
                     onChanged: (val) {
                       ref.read(playerControllerProvider(widget.params).notifier).updateSubtitleDelay(val);
                     },
                   ),
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
  Widget _buildDisableTrackTile(Player player, dynamic noTrack, dynamic selectedTrack) {
    return TrackTile(
      player: player,
      track: noTrack,
      isSelected: selectedTrack.id == 'no',
      isSubtitle: widget.isSubtitle,
      customTitle: widget.isSubtitle ? "Off / Disable" : "No Audio / Mute",
      color: AppTheme.textMuted,
      onBack: widget.onBack,
      onSelected: () => _notifyManualSelection(),
    );
  }

  /// Builds the "INTERNAL TRACKS" section header and track list.
  Widget _buildInternalTracks(Player player, List<dynamic> tracks, dynamic selectedTrack, String prefLang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(widget.isSubtitle ? "INTERNAL TRACKS" : "AUDIO TRACKS"),
        Builder(
          builder: (context) {
            bool foundAutoMatch = false;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: tracks.map((track) {
                bool isSelected = selectedTrack.id == track.id;
                
                if (!isSelected && selectedTrack.id == 'auto' && !foundAutoMatch && LanguageMapper.isMatch(track, prefLang)) {
                  isSelected = true;
                  foundAutoMatch = true;
                }

                return TrackTile(
                  player: player,
                  track: track,
                  isSelected: isSelected,
                  isSubtitle: widget.isSubtitle,
                  onBack: widget.onBack,
                  onSelected: () => _notifyManualSelection(),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  /// Builds the "EXTERNAL TRACKS" section with grouped, expandable language folders.
  Widget _buildExternalTracks(Player player, AsyncValue<List<ExternalSubtitle>> externalSubsAsync, bool isLandscape) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader("EXTERNAL TRACKS"),
        externalSubsAsync.when(
          data: (subs) => _buildExternalSubtitleList(player, subs, isLandscape),
          loading: () => const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, st) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(child: Text("Error: $e", style: const TextStyle(color: Colors.redAccent))),
          ),
        ),
      ],
    );
  }

  /// Builds the grouped language folders for external subtitles.
  Widget _buildExternalSubtitleList(Player player, List<ExternalSubtitle> subs, bool isLandscape) {
    if (subs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: Text("No external subtitles found.", style: TextStyle(color: AppTheme.textMuted, fontSize: 13))),
      );
    }

    final grouped = <String, List<ExternalSubtitle>>{};
    for (var sub in subs) {
      grouped.putIfAbsent(sub.languageName, () => []).add(sub);
    }

    return Column(
      children: grouped.entries.map((entry) => _buildLanguageFolder(
        player: player,
        language: entry.key,
        subtitles: entry.value,
        isLandscape: isLandscape,
      )).toList(),
    );
  }

  /// Builds a single expandable language folder with its subtitle entries.
  Widget _buildLanguageFolder({
    required Player player,
    required String language,
    required List<ExternalSubtitle> subtitles,
    required bool isLandscape,
  }) {
    final isExpanded = _expandedLanguages[language] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _expandedLanguages[language] = !isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: isLandscape ? 8 : 12),
              child: Row(
                children: [
                  const Icon(Icons.folder_open_rounded, color: AppTheme.accent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          language.toUpperCase(),
                          style: const TextStyle(color: AppTheme.textWhite, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                        Text(
                          "${subtitles.length} subtitles",
                          style: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.8), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isExpanded) ...[
          const SizedBox(height: 4),
          ...subtitles.map((sub) => _ExternalSubtitleTile(
            subtitle: sub,
            player: player,
            onBack: widget.onBack,
            params: widget.params,
          )),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Widget _sectionHeader(String label) => Padding(
    padding: const EdgeInsets.only(left: 8, bottom: 8),
    child: Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
  );

  void _notifyManualSelection() =>
      ref.read(playerControllerProvider(widget.params).notifier).setManualTrackSelection();
}

// =============================================================================
// External Subtitle Tile
// =============================================================================

class _ExternalSubtitleTile extends ConsumerStatefulWidget {
  final ExternalSubtitle subtitle;
  final Player player;
  final VoidCallback onBack;
  final PlayerParams params;

  const _ExternalSubtitleTile({
    required this.subtitle,
    required this.player,
    required this.onBack,
    required this.params,
  });

  @override
  ConsumerState<_ExternalSubtitleTile> createState() => _ExternalSubtitleTileState();
}

class _ExternalSubtitleTileState extends ConsumerState<_ExternalSubtitleTile> {
  bool _isApplying = false;

  Future<void> _apply() async {
    if (_isApplying) return;
    setState(() => _isApplying = true);

    try {
      final service = ref.read(subtitleServiceProvider);
      final url = await service.getDownloadUrl(widget.subtitle);
      if (url != null && url.isNotEmpty) {
        final track = SubtitleTrack.uri(url, title: widget.subtitle.title, language: widget.subtitle.language);
        await widget.player.setSubtitleTrack(track);
        ref.read(playerControllerProvider(widget.params).notifier).setManualTrackSelection();
        widget.onBack();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load external subtitle.')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.subtitle;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isApplying ? null : _apply,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sub.title,
                        style: TextStyle(color: AppTheme.textWhite.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w400),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          SettingsBadge(text: sub.providerName, color: AppTheme.accent),
                          if (sub.downloadCount != null)
                             SettingsBadge(text: "\u2193 ${sub.downloadCount}", color: Colors.blueAccent),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (_isApplying)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  const Icon(LucideIcons.download, color: AppTheme.textMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Subtitle Sync Adjustment
// =============================================================================

class _SubtitleSyncAdjustment extends StatelessWidget {
  final double delaySeconds;
  final ValueChanged<double> onChanged;

  const _SubtitleSyncAdjustment({
    required this.delaySeconds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24.0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.playerSubtitleDelay, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              Text(
                '${delaySeconds > 0 ? '+' : ''}${delaySeconds.toStringAsFixed(1)} s',
                style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: const Icon(LucideIcons.minus, color: Colors.white70),
                onPressed: () => onChanged(delaySeconds - 0.5),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                    activeTrackColor: AppTheme.accent,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: AppTheme.accent,
                  ),
                  child: Slider(
                    value: delaySeconds.clamp(-15.0, 15.0),
                    min: -15.0,
                    max: 15.0,
                    divisions: 60,
                    onChanged: onChanged,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.plus, color: Colors.white70),
                onPressed: () => onChanged(delaySeconds + 0.5),
              ),
            ],
          ),
          Center(
            child: TextButton(
              onPressed: delaySeconds == 0 ? null : () => onChanged(0.0),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textMuted,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(l10n.playerSubtitleDelayReset, style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
