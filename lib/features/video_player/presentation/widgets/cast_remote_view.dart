
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CastRemoteView extends ConsumerWidget {
  final CinemaPlayerState playerState;
  final PlayerParams params;
  final VoidCallback onBackPressed;

  const CastRemoteView({
    super.key,
    required this.playerState,
    required this.params,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(playerControllerProvider(params).notifier);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Gradient or Backdrop
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.2),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: onBackPressed,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              playerState.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Casting to ${playerState.selectedCastDevice?.name ?? "Chromecast"}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.cast_connected, color: theme.colorScheme.primary),
                        onPressed: () => notifier.stopCasting(),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Media Poster/Placeholder
                Flexible(
                  child: Container(
                    width: 200,
                    height: 300,
                    constraints: const BoxConstraints(maxHeight: 300),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          blurRadius: 40,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.movie, size: 80, color: Colors.white24),
                  ),
                ),

                const SizedBox(height: 32),

                // Title and Info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        playerState.title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (params.type == 'tv' && params.season != null && params.episode != null)
                        Text(
                          'Season ${params.season} • Episode ${params.episode}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white60,
                          ),
                        ),
                    ],
                  ),
                ),

                // Progress Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: theme.colorScheme.primary,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: theme.colorScheme.primary,
                        ),
                        child: Slider(
                          value: playerState.remotePosition.inSeconds.toDouble().clamp(
                            0, 
                            playerState.remoteDuration.inSeconds.toDouble().clamp(1, double.infinity)
                          ),
                          max: playerState.remoteDuration.inSeconds.toDouble().clamp(1, double.infinity),
                          onChanged: (value) {
                            notifier.seek(Duration(seconds: value.toInt()));
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(playerState.remotePosition),
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            Text(
                              _formatDuration(playerState.remoteDuration),
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Playback Controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        iconSize: 40,
                        icon: const Icon(Icons.replay_10, color: Colors.white),
                        onPressed: () {
                          notifier.seek(playerState.remotePosition - const Duration(seconds: 10));
                        },
                      ),
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: theme.colorScheme.primary,
                        child: IconButton(
                          iconSize: 50,
                          icon: Icon(
                            playerState.remotePlaying 
                                ? Icons.pause 
                                : Icons.play_arrow,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            if (playerState.remotePlaying) {
                              notifier.pause();
                            } else {
                              notifier.play();
                            }
                          },
                        ),
                      ),
                      IconButton(
                        iconSize: 40,
                        icon: const Icon(Icons.forward_10, color: Colors.white),
                        onPressed: () {
                          notifier.seek(playerState.remotePosition + const Duration(seconds: 10));
                        },
                      ),
                    ],
                  ),
                ),

                // Dedicated Stop Button
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    icon: const Icon(Icons.stop),
                    label: const Text('STOP CASTING'),
                    onPressed: () => notifier.stopCasting(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
