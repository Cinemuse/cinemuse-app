import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/custom_video_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class VideoPlayerScreen extends ConsumerWidget {
  final String queryId;
  final String type;
  final int? season;
  final int? episode;
  final String? episodeTitle;
  final int startPosition;

  const VideoPlayerScreen({
    super.key,
    required this.queryId,
    required this.type,
    this.season,
    this.episode,
    this.episodeTitle,
    this.startPosition = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Construct params
    final params = PlayerParams(
      queryId, 
      type, 
      season: season, 
      episode: episode, 
      episodeTitle: episodeTitle,
      startPosition: startPosition,
    );
    final playerState = ref.watch(playerControllerProvider(params));

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: playerState.when(
        data: (state) => Center(
          child: Video(
            controller: state.controller,
            controls: (videoState) => CustomVideoControls(
              videoState: videoState,
              playerState: state,
              params: params,
              onSettingsPressed: () => _showSettings(context, ref, state, params),
              onNextEpisode: state.nextEpisode != null ? () {
                final next = state.nextEpisode!;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => VideoPlayerScreen(
                      queryId: queryId,
                      type: type,
                      season: next.season,
                      episode: next.episode,
                      episodeTitle: next.title,
                    ),
                  ),
                );
              } : null,
            ),
          ),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Theme.of(context).colorScheme.error, size: 48),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.playerErrorResolving(err.toString()),
                style: const TextStyle(color: AppTheme.textWhite),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(playerControllerProvider(params)),
                child: Text(AppLocalizations.of(context)!.commonRetry),
              )
            ],
          ),
        ),
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.playerResolving,
                style: const TextStyle(color: AppTheme.textMuted),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showSettings(BuildContext context, WidgetRef ref, CinemaPlayerState state, PlayerParams params) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(AppLocalizations.of(context)!.playerSettings, style: const TextStyle(color: AppTheme.textWhite, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.high_quality, color: AppTheme.textWhite),
              title: Text(AppLocalizations.of(context)!.playerQuality, style: const TextStyle(color: AppTheme.textWhite)),
              subtitle: () {
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
                      if (meta['resolution'] != null) _buildBadge(meta['resolution'], AppTheme.accent),
                      for (var q in (meta['quality'] as List? ?? [])) _buildBadge(q, Colors.blueGrey),
                      if (meta['codec'] != null) _buildBadge(meta['codec'], Colors.teal),
                      for (var a in (meta['audio'] as List? ?? [])) _buildBadge(a, Colors.deepPurpleAccent),
                      for (var l in (meta['languages'] as List? ?? [])) _buildBadge(l, Colors.orange),
                    ],
                  ),
                );
              }(),
              onTap: () {
                Navigator.pop(ctx);
                _showQualitySelector(context, ref, state, params);
              },
            ),
            ListTile(
              leading: const Icon(Icons.audiotrack, color: AppTheme.textWhite),
              title: Text(AppLocalizations.of(context)!.playerAudio, style: const TextStyle(color: AppTheme.textWhite)),
              subtitle: Builder(
                builder: (context) {
                  final audio = state.controller.player.state.track.audio;
                  final tracks = state.controller.player.state.tracks.audio;
                  
                  if (audio.id == 'auto' || audio.id == 'no') {
                     // If still 'auto', it means we are waiting for discovery or _applyLanguagePreference to kick in
                     if (tracks.any((t) => t.id != 'no' && t.id != 'auto')) {
                        final firstTrack = tracks.firstWhere((t) => t.id != 'no' && t.id != 'auto');
                        return Text(
                          _getLanguageDisplayName(firstTrack.title ?? firstTrack.language ?? firstTrack.id),
                          style: const TextStyle(color: AppTheme.textMuted),
                        );
                     }
                     return Text(
                       audio.id == 'no' ? 'None' : 'Loading tracks...',
                       style: const TextStyle(color: AppTheme.textMuted),
                     );
                  }
                  
                  return Text(
                    _getLanguageDisplayName(audio.title ?? audio.language ?? audio.id),
                    style: const TextStyle(color: AppTheme.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showAudioSelector(context, state.controller.player);
              },
            ),
            ListTile(
              leading: const Icon(Icons.subtitles, color: AppTheme.textWhite),
              title: Text(AppLocalizations.of(context)!.playerSubtitles, style: const TextStyle(color: AppTheme.textWhite)),
              subtitle: Builder(
                builder: (context) {
                  final subtitle = state.controller.player.state.track.subtitle;
                  if (subtitle.id == 'no' || subtitle.id == 'auto') {
                    return const Text('Off', style: TextStyle(color: AppTheme.textMuted));
                  }
                  return Text(
                    _getLanguageDisplayName(subtitle.title ?? subtitle.language ?? subtitle.id),
                    style: const TextStyle(color: AppTheme.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showSubtitleSelector(context, state.controller.player);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showQualitySelector(BuildContext context, WidgetRef ref, CinemaPlayerState state, PlayerParams params) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          final currentStream = state.currentStream;
          
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  AppLocalizations.of(context)!.playerSelectQuality, 
                  style: const TextStyle(color: AppTheme.textWhite, fontSize: 20, fontWeight: FontWeight.bold)
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: state.availableStreams.length,
                  separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, index) {
                    final stream = state.availableStreams[index];
                    final meta = stream['metadata'] as Map<String, dynamic>? ?? {};
                    final isSelected = stream['infoHash'] == currentStream['infoHash'] || (stream['url'] != null && stream['url'] == currentStream['url']);
                    
                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        ref.read(playerControllerProvider(params).notifier).changeSource(stream);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        color: isSelected ? AppTheme.accent.withOpacity(0.1) : null,
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
                                      if (stream['cached'] == true)
                                        _buildBadge('CACHED', Colors.greenAccent),
                                      
                                      if (meta['resolution'] != null)
                                        _buildBadge(meta['resolution'], Colors.blueAccent),
                                      
                                      if (meta['quality'] != null)
                                        ...(meta['quality'] as List).map((q) => _buildBadge(q.toString(), Colors.orangeAccent)),
                                      
                                      if (meta['languages'] != null)
                                        ...(meta['languages'] as List).map((l) => _buildBadge(l.toString(), Colors.white)),
                                      
                                      Text(
                                        '• ${stream['provider']}',
                                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check_circle, color: AppTheme.accent, size: 20),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              stream['title'] ?? 'Unknown',
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppTheme.textMuted,
                                fontSize: 13,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAudioSelector(BuildContext context, Player player) {
    var tracks = player.state.tracks.audio;
    final selectedTrack = player.state.track.audio;
    
    // Filter out 'no' and 'auto'
    final regularTracks = tracks.where((t) => t.id != 'no' && t.id != 'auto').toList();
    final noAudioTrack = tracks.where((t) => t.id == 'no').firstOrNull ?? AudioTrack.no();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(AppLocalizations.of(context)!.playerSelectAudio, style: const TextStyle(color: AppTheme.textWhite, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    if (regularTracks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text("No audio tracks found", style: TextStyle(color: AppTheme.textMuted)),
                      )
                    else
                      ...regularTracks.map((track) => _buildTrackTile(
                        context, 
                        player, 
                        track, 
                        selectedTrack == track,
                      )),
                      
                    const Divider(color: Colors.white10, height: 32),
                    _buildTrackTile(
                      context, 
                      player, 
                      noAudioTrack, 
                      selectedTrack == noAudioTrack,
                      title: "No Audio / Mute",
                      color: AppTheme.textMuted,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSubtitleSelector(BuildContext context, Player player) {
    var tracks = player.state.tracks.subtitle;
    final selectedTrack = player.state.track.subtitle;
    
    // Filter out 'no' and 'auto'
    final regularTracks = tracks.where((t) => t.id != 'no' && t.id != 'auto').toList();
    final noSubtitleTrack = tracks.where((t) => t.id == 'no').firstOrNull ?? SubtitleTrack.no();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(AppLocalizations.of(context)!.playerSelectSubtitle, style: const TextStyle(color: AppTheme.textWhite, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    if (regularTracks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text("No internal subtitles found", style: TextStyle(color: AppTheme.textMuted)),
                      )
                    else
                      ...regularTracks.map((track) => _buildTrackTile(
                        context, 
                        player, 
                        track, 
                        selectedTrack == track,
                        isSubtitle: true,
                      )),
                      
                    const Divider(color: Colors.white10, height: 32),
                    _buildTrackTile(
                      context, 
                      player, 
                      noSubtitleTrack, 
                      selectedTrack == noSubtitleTrack,
                      title: "Off / Disable",
                      color: AppTheme.textMuted,
                      isSubtitle: true,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTrackTile(
    BuildContext context, 
    Player player, 
    dynamic track, 
    bool isSelected, 
    {String? title, bool isAuto = false, Color? color, bool isSubtitle = false}
  ) {
    String displayTitle = title ?? _getLanguageDisplayName(track.title ?? track.language ?? track.id);
    
    // Improved selection check
    bool isActuallySelected = isSelected;
    
    if (!isSubtitle) {
      final currentAudio = player.state.track.audio;
      isActuallySelected = isSelected || 
          (currentAudio.id == 'auto' && track.id != 'no' && track.id != 'auto' && track == player.state.tracks.audio.firstWhere((t) => t.id != 'no' && t.id != 'auto', orElse: () => track));
    }

    return ListTile(
      title: Text(
        displayTitle,
        style: TextStyle(
          color: isActuallySelected ? (color ?? AppTheme.accent) : AppTheme.textWhite,
          fontWeight: isActuallySelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isActuallySelected ? Icon(Icons.check, color: color ?? AppTheme.accent) : null,
      onTap: () {
        if (isSubtitle) {
          player.setSubtitleTrack(track);
        } else {
          player.setAudioTrack(track);
        }
        Navigator.pop(context);
      },
    );
  }

  String _getLanguageDisplayName(String lang) {
    final l = lang.toLowerCase();
    
    // Map of common codes to full names
    const map = {
      'it': 'Italiano',
      'ita': 'Italiano',
      'italian': 'Italiano',
      'en': 'English',
      'eng': 'English',
      'english': 'English',
      'fr': 'Français',
      'fra': 'Français',
      'fre': 'Français',
      'french': 'Français',
      'de': 'Deutsch',
      'deu': 'Deutsch',
      'ger': 'Deutsch',
      'german': 'Deutsch',
      'es': 'Español',
      'spa': 'Español',
      'spanish': 'Español',
      'ru': 'Русский',
      'rus': 'Русский',
      'russian': 'Русский',
      'ja': '日本語',
      'jpn': '日本語',
      'japanese': '日本語',
      'ko': '한국어',
      'kor': '한국어',
      'korean': '한국어',
      'zh': '中文',
      'chi': '中文',
      'zho': '中文',
      'chinese': '中文',
      'sdh': 'SDH (Hard of Hearing)',
    };

    final mapped = map[l];
    if (mapped != null) return mapped;

    // Handle pure numeric IDs (usually indices or unnamed tracks)
    if (RegExp(r'^\d+$').hasMatch(lang)) {
      return 'Track $lang';
    }

    return lang;
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
