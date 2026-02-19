import 'package:flutter/material.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';

class VideoTopBar extends StatelessWidget {
  final CinemaPlayerState playerState;
  final PlayerParams params;
  final VoidCallback onSettingsPressed;
  final VoidCallback onCastPressed;
  final VoidCallback onBackPressed;

  const VideoTopBar({
    super.key,
    required this.playerState,
    required this.params,
    required this.onSettingsPressed,
    required this.onCastPressed,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onBackPressed,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  playerState.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (params.type == 'tv' && params.season != null && params.episode != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'S${params.season.toString().padLeft(2, '0')}E${params.episode.toString().padLeft(2, '0')}${params.episodeTitle != null ? ' - ${params.episodeTitle}' : ''}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              playerState.isCasting ? Icons.cast_connected : Icons.cast, 
              color: playerState.isCasting ? Colors.blueAccent : Colors.white
            ),
            onPressed: onCastPressed,
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: onSettingsPressed,
          ),
        ],
      ),
    );
  }
}
