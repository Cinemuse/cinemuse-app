import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/application/language_mapper.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class PlayerSettingsBottomSheet extends ConsumerWidget {
  final CinemaPlayerState state;
  final PlayerParams params;

  const PlayerSettingsBottomSheet({
    super.key,
    required this.state,
    required this.params,
  });

  static void show(BuildContext context, CinemaPlayerState state, PlayerParams params) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      isScrollControlled: true,
      builder: (ctx) => PlayerSettingsBottomSheet(state: state, params: params),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.glass.withOpacity(0.8),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppTheme.border.withOpacity(0.1), width: 1.5),
        ),
        padding: const EdgeInsets.only(bottom: 24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  l10n.playerSettings.toUpperCase(), 
                  style: TextStyle(
                    color: AppTheme.textWhite.withOpacity(0.9), 
                    fontSize: 14, 
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.high_quality_rounded,
                title: l10n.playerQuality,
                subtitle: _QualitySubtitle(state: state),
                onTap: () {
                  _QualitySelector.show(context, state, params);
                },
              ),
              _SettingsTile(
                icon: Icons.audiotrack_rounded,
                title: l10n.playerAudio,
                subtitle: _TrackSubtitle(player: state.controller.player, isSubtitle: false),
                onTap: () {
                  _TrackSelector.show(context, state.controller.player, isSubtitle: false);
                },
              ),
              _SettingsTile(
                icon: Icons.subtitles_rounded,
                title: l10n.playerSubtitles,
                subtitle: _TrackSubtitle(player: state.controller.player, isSubtitle: true),
                onTap: () {
                  _TrackSelector.show(context, state.controller.player, isSubtitle: true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.accent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppTheme.accent, size: 24),
      ),
      title: Text(
        title, 
        style: const TextStyle(
          color: AppTheme.textWhite, 
          fontSize: 16, 
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle,
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
      onTap: onTap,
    );
  }
}

class _QualitySubtitle extends StatelessWidget {
  final CinemaPlayerState state;
  const _QualitySubtitle({required this.state});

  @override
  Widget build(BuildContext context) {
    final currentStream = state.currentStream;
    final meta = currentStream['metadata'] as Map<String, dynamic>?;
    
    if (meta == null || currentStream['tag'] == 'youtube') {
      return Text(
        currentStream['title'] ?? 'Unknown', 
        style: const TextStyle(color: AppTheme.textMuted),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          if (meta['resolution'] != null) _Badge(text: meta['resolution'], color: AppTheme.accent),
          if (meta['size'] != null) _Badge(text: meta['size'], color: Colors.cyanAccent),
          for (var q in (meta['quality'] as List? ?? [])) _Badge(text: q.toString(), color: Colors.blueGrey),
          if (meta['codec'] != null) _Badge(text: meta['codec'], color: Colors.teal),
          for (var a in (meta['audio'] as List? ?? [])) _Badge(text: a.toString(), color: Colors.deepPurpleAccent),
          for (var l in (meta['languages'] as List? ?? [])) _Badge(text: l.toString(), color: Colors.orange),
        ],
      ),
    );
  }
}

class _TrackSubtitle extends ConsumerWidget {
  final Player player;
  final bool isSubtitle;
  const _TrackSubtitle({required this.player, required this.isSubtitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isSubtitle) {
      final track = player.state.track.subtitle;
      final pref = ref.watch(settingsProvider).playerLanguage.toLowerCase();
      
      if (track.id == 'no' || track.id == 'auto') {
        if (track.id == 'no') return const Text('Off/None', style: TextStyle(color: AppTheme.textMuted));
        
        // If Auto, find matching sub or default to first
        final subs = player.state.tracks.subtitle;
        final matched = subs.firstWhere((t) => t.id != 'auto' && t.id != 'no' && LanguageMapper.isMatch(t, pref), orElse: () => subs.firstOrNull ?? track);
        
        final name = LanguageMapper.getDisplayLanguage(matched.title ?? matched.language ?? matched.id);
        return Text(name, style: const TextStyle(color: AppTheme.textMuted));
      }
      
      final name = LanguageMapper.getDisplayLanguage(track.title ?? track.language ?? track.id);
      return Text(name, style: const TextStyle(color: AppTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis);
    } else {
      final track = player.state.track.audio;
      final pref = ref.watch(settingsProvider).playerLanguage.toLowerCase();
      
      if (track.id == 'no' || track.id == 'auto') {
        if (track.id == 'no') return const Text('Off/None', style: TextStyle(color: AppTheme.textMuted));
        
        // If Auto, find matching audio or default to first
        final audio = player.state.tracks.audio;
        final matched = audio.firstWhere((t) => t.id != 'auto' && t.id != 'no' && LanguageMapper.isMatch(t, pref), orElse: () => audio.firstOrNull ?? track);
        
        final name = LanguageMapper.getDisplayLanguage(matched.title ?? matched.language ?? matched.id);
        return Text(name, style: const TextStyle(color: AppTheme.textMuted));
      }
      
      final name = LanguageMapper.getDisplayLanguage(track.title ?? track.language ?? track.id);
      return Text(name, style: const TextStyle(color: AppTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis);
    }
  }
}

class _QualitySelector extends ConsumerStatefulWidget {
  final CinemaPlayerState state;
  final PlayerParams params;

  const _QualitySelector({required this.state, required this.params});

  static void show(BuildContext context, CinemaPlayerState state, PlayerParams params) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _QualitySelector(state: state, params: params),
    );
  }

  @override
  ConsumerState<_QualitySelector> createState() => _QualitySelectorState();
}

class _QualitySelectorState extends ConsumerState<_QualitySelector> {
  bool _filesExpanded = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final params = widget.params;
    
    // Sort files alphabetically by filename
    final sortedFiles = List<Map<String, dynamic>>.from(state.activeTorrentFiles);
    sortedFiles.sort((a, b) {
      final nameA = (a['path'] as String? ?? '').split('/').last.toLowerCase();
      final nameB = (b['path'] as String? ?? '').split('/').last.toLowerCase();
      return nameA.compareTo(nameB);
    });

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          final l10n = AppLocalizations.of(context)!;
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.glass.withOpacity(0.8),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: AppTheme.border.withOpacity(0.1), width: 1.5),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 12, right: 24, bottom: 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                        splashRadius: 24,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.playerSelectQuality.toUpperCase(), 
                        style: TextStyle(
                          color: AppTheme.textWhite.withOpacity(0.9), 
                          fontSize: 14, 
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      // Files Section (Accordion)
                      if (state.activeTorrentFiles.isNotEmpty) ...[
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => setState(() => _filesExpanded = !_filesExpanded),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.folder_open_rounded, color: AppTheme.accent, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.playerFiles.toUpperCase(),
                                          style: const TextStyle(
                                            color: AppTheme.textWhite, 
                                            fontSize: 13, 
                                            fontWeight: FontWeight.bold, 
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        Text(
                                          "${state.activeTorrentFiles.length} files available",
                                          style: TextStyle(color: AppTheme.textMuted.withOpacity(0.5), fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    _filesExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                    color: AppTheme.textMuted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        if (_filesExpanded) ...[
                          const SizedBox(height: 8),
                          ...sortedFiles.map((file) {
                            final isSelected = file['id'] == state.activeFileId;
                            final fileName = (file['path'] as String).split('/').last;
                            final size = (file['bytes'] as int? ?? 0) / (1024 * 1024 * 1024); // GB
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    Navigator.pop(context);
                                    ref.read(playerControllerProvider(params).notifier).changeFile(file['id']);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppTheme.accent.withOpacity(0.12) : Colors.white.withOpacity(0.04),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? AppTheme.accent.withOpacity(0.6) : Colors.white.withOpacity(0.08),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                fileName,
                                                style: TextStyle(
                                                  color: isSelected ? Colors.white : AppTheme.textWhite.withOpacity(0.7),
                                                  fontSize: 13,
                                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                "${size.toStringAsFixed(2)} GB",
                                                style: TextStyle(color: AppTheme.textMuted.withOpacity(0.5), fontSize: 10),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected) const Icon(Icons.check_circle_rounded, color: AppTheme.accent, size: 18),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                        const Divider(color: Colors.white10, height: 32),
                      ],

                      // Sources Section
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 8, top: 12),
                        child: Text(
                          l10n.playerQuality.toUpperCase(),
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                      ),
                      ...List.generate(state.availableStreams.length, (index) {
                        final stream = state.availableStreams[index];
                        final meta = stream['metadata'] as Map<String, dynamic>? ?? {};
                        final isSelected = stream['infoHash'] == state.currentStream['infoHash'] || (stream['url'] != null && stream['url'] == state.currentStream['url']);
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.pop(context);
                                ref.read(playerControllerProvider(params).notifier).changeSource(stream);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.accent.withOpacity(0.1) : Colors.white.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.accent.withOpacity(0.5) : Colors.white.withOpacity(0.05),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              if (stream['cached'] == true) _Badge(text: 'CACHED', color: Colors.greenAccent),
                                              if (meta['resolution'] != null) _Badge(text: meta['resolution'], color: Colors.blueAccent),
                                              if (meta['size'] != null) _Badge(text: meta['size'], color: Colors.cyanAccent),
                                              if (meta['quality'] != null) ...(meta['quality'] as List).map((q) => _Badge(text: q.toString(), color: Colors.orangeAccent)),
                                              if (meta['languages'] != null) ...(meta['languages'] as List).map((l) => _Badge(text: l.toString(), color: Colors.white70)),
                                            ],
                                          ),
                                        ),
                                        if (isSelected) const Icon(Icons.check_circle_rounded, color: AppTheme.accent, size: 20),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      stream['title'] ?? 'Unknown',
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : AppTheme.textMuted, 
                                        fontSize: 13, 
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                        height: 1.4,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      stream['provider'] ?? 'Unknown Provider', 
                                      style: TextStyle(color: AppTheme.textMuted.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TrackSelector extends ConsumerWidget {
  final Player player;
  final bool isSubtitle;

  const _TrackSelector({required this.player, required this.isSubtitle});

  static void show(BuildContext context, Player player, {required bool isSubtitle}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _TrackSelector(player: player, isSubtitle: isSubtitle),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = isSubtitle ? player.state.tracks.subtitle : player.state.tracks.audio;
    final selectedTrack = isSubtitle ? player.state.track.subtitle : player.state.track.audio;
    final pref = ref.watch(settingsProvider).playerLanguage.toLowerCase();
    
    final regularTracks = tracks.where((t) => t.id != 'no' && t.id != 'auto').toList();
    final noTrack = tracks.where((t) => t.id == 'no').firstOrNull ?? (isSubtitle ? SubtitleTrack.no() : AudioTrack.no());

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) {
          final l10n = AppLocalizations.of(context)!;
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.glass.withOpacity(0.8),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: AppTheme.border.withOpacity(0.1), width: 1.5),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 12, right: 24, bottom: 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                        splashRadius: 24,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        (isSubtitle ? l10n.playerSelectSubtitle : l10n.playerSelectAudio).toUpperCase(),
                        style: TextStyle(
                          color: AppTheme.textWhite.withOpacity(0.9), 
                          fontSize: 14, 
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      const SizedBox(height: 12),
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
                        ...regularTracks.map((track) {
                          // Logic for highlighting when still in 'auto' mode
                          final isSelected = selectedTrack.id == track.id || 
                                           (selectedTrack.id == 'auto' && LanguageMapper.isMatch(track, pref));
                          
                          return _TrackTile(
                            player: player,
                            track: track,
                            isSelected: isSelected,
                            isSubtitle: isSubtitle,
                          );
                        }),
                      const Divider(color: Colors.white10, height: 32, indent: 16, endIndent: 16),
                      _TrackTile(
                        player: player,
                        track: noTrack,
                        isSelected: selectedTrack.id == 'no',
                        isSubtitle: isSubtitle,
                        customTitle: isSubtitle ? "Off / Disable" : "No Audio / Mute",
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  final Player player;
  final dynamic track;
  final bool isSelected;
  final bool isSubtitle;
  final String? customTitle;
  final Color? color;

  const _TrackTile({
    required this.player,
    required this.track,
    required this.isSelected,
    required this.isSubtitle,
    this.customTitle,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final title = customTitle ?? LanguageMapper.getDisplayLanguage(track.title ?? track.language ?? track.id);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.accent.withOpacity(0.1) : Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppTheme.accent.withOpacity(0.5) : Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? (color ?? AppTheme.textWhite) : AppTheme.textWhite.withOpacity(0.7),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 15,
          ),
        ),
        trailing: isSelected 
            ? Icon(Icons.check_circle_rounded, color: color ?? AppTheme.accent, size: 20) 
            : null,
        onTap: () {
          if (isSubtitle) {
            player.setSubtitleTrack(track);
          } else {
            player.setAudioTrack(track);
          }
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color, 
          fontSize: 10, 
          fontWeight: FontWeight.w800, 
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
