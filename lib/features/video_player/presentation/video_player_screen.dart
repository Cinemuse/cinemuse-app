
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
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
  final int startPosition;

  const VideoPlayerScreen({
    super.key,
    required this.queryId,
    required this.type,
    this.season,
    this.episode,
    this.startPosition = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Construct params
    final params = PlayerParams(queryId, type, season: season, episode: episode, startPosition: startPosition);
    final playerState = ref.watch(playerControllerProvider(params));

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: playerState.when(
        data: (state) => Stack(
          children: [
            Center(
              child: Video(controller: state.controller),
            ),
            // Back Button
            Positioned(
              top: 40,
              left: 20,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.textWhite),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            // Settings Button
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.settings, color: AppTheme.textWhite),
                onPressed: () => _showSettings(context, ref, state, params),
              ),
            ),
          ],
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
              subtitle: Text(
                state.currentStream['title'] ?? 'Unknown', 
                style: const TextStyle(color: AppTheme.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showQualitySelector(context, ref, state, params);
              },
            ),
            ListTile(
              leading: const Icon(Icons.audiotrack, color: AppTheme.textWhite),
              title: Text(AppLocalizations.of(context)!.playerAudio, style: const TextStyle(color: AppTheme.textWhite)),
              subtitle: Text(
                state.controller.player.state.track.audio.toString(),
                style: const TextStyle(color: AppTheme.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showAudioSelector(context, state.controller.player);
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
               Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(AppLocalizations.of(context)!.playerSelectQuality, style: const TextStyle(color: AppTheme.textWhite, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: state.availableStreams.length,
                  itemBuilder: (context, index) {
                    final stream = state.availableStreams[index];
                    final isSelected = stream == state.currentStream;
                    return ListTile(
                      title: Text(
                        stream['title'] ?? "Unknown",
                        style: TextStyle(
                          color: isSelected ? AppTheme.accent : AppTheme.textWhite,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: stream['tag'] == 'youtube' 
                        ? null 
                        : Text(
                            "${stream['cached'] == true ? '⚡ Cached' : '⏳ Uncached'} • Seeds: ${stream['seeds']}",
                            style: const TextStyle(color: AppTheme.textMuted),
                          ),
                      trailing: isSelected ? const Icon(Icons.check, color: AppTheme.accent) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        if (!isSelected) {
                          ref.read(playerControllerProvider(params).notifier)
                             .changeSource(stream);
                        }
                      },
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
    final tracks = player.state.tracks.audio;
    final currentTrack = player.state.track.audio;

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
              child: Text(AppLocalizations.of(context)!.playerSelectAudio, style: const TextStyle(color: AppTheme.textWhite, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            if (tracks.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(AppLocalizations.of(context)!.playerNoAudioFound, style: const TextStyle(color: AppTheme.textMuted)),
              )
            else
              ...tracks.map((track) {
                final isSelected = track == currentTrack;
                return ListTile(
                  title: Text(
                    track.id == 'auto' ? 'Auto' : (track.title ?? track.language ?? track.id),
                    style: TextStyle(
                      color: isSelected ? AppTheme.accent : AppTheme.textWhite,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected ? const Icon(Icons.check, color: AppTheme.accent) : null,
                  onTap: () {
                     player.setAudioTrack(track);
                     Navigator.pop(ctx);
                  },
                );
              }),
          ],
        ),
      ),
    );
  }
}
