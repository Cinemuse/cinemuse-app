
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class VideoPlayerScreen extends ConsumerWidget {
  final String queryId;
  final String type;
  final int? season;
  final int? episode;

  const VideoPlayerScreen({
    super.key,
    required this.queryId,
    required this.type,
    this.season,
    this.episode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Construct params
    final params = PlayerParams(queryId, type, season: season, episode: episode);
    final playerState = ref.watch(playerControllerProvider(params));

    return Scaffold(
      backgroundColor: Colors.black,
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
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            // Settings Button
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                onPressed: () => _showSettings(context, ref, state, params),
              ),
            ),
          ],
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                "Error resolving stream:\n$err",
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(playerControllerProvider(params)),
                child: const Text('Retry'),
              )
            ],
          ),
        ),
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                "Resolving stream with Real-Debrid...",
                style: TextStyle(color: Colors.white70),
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
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Settings", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.high_quality, color: Colors.white),
              title: const Text('Quality', style: TextStyle(color: Colors.white)),
              subtitle: Text(
                state.currentStream['title'] ?? 'Unknown', 
                style: const TextStyle(color: Colors.white70),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showQualitySelector(context, ref, state, params);
              },
            ),
            ListTile(
              leading: const Icon(Icons.audiotrack, color: Colors.white),
              title: const Text('Audio', style: TextStyle(color: Colors.white)),
              subtitle: Text(
                state.controller.player.state.track.audio.toString(),
                style: const TextStyle(color: Colors.white70),
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
      backgroundColor: Colors.grey[900],
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
               const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("Select Quality", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                          color: isSelected ? Colors.blue : Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        "${stream['cached'] == true ? '⚡ Cached' : '⏳ Uncached'} • Seeds: ${stream['seeds']}",
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
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
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Select Audio Track", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            if (tracks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("No audio tracks found", style: TextStyle(color: Colors.white70)),
              )
            else
              ...tracks.map((track) {
                final isSelected = track == currentTrack;
                return ListTile(
                  title: Text(
                    track.id == 'auto' ? 'Auto' : (track.title ?? track.language ?? track.id),
                    style: TextStyle(
                      color: isSelected ? Colors.blue : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
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
