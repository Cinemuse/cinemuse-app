import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/application/l10n_provider.dart';

class VideoTopBar extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(localizationsProvider);
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
            icon: const Icon(Icons.arrow_back, color: AppTheme.textWhite),
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
                    color: AppTheme.textWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (params.type == 'tv' && params.season != null && params.episode != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${l10n.detailsSeasonNumber(params.season!)}, ${l10n.detailsEpisodeNumber(params.episode!)}${params.episodeTitle != null ? ' - ${params.episodeTitle}' : ''}',
                    style: TextStyle(
                      color: AppTheme.textWhite.withOpacity(0.7),
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
              color: playerState.isCasting ? Colors.blueAccent : AppTheme.textWhite
            ),
            onPressed: onCastPressed,
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: AppTheme.textWhite),
            onPressed: onSettingsPressed,
          ),
        ],
      ),
    );
  }
}
