import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/application/l10n_provider.dart';

import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';

/// Title / channel info shown at the top of the player.
///
/// Info only, no buttons: Stop and Settings live in the bottom bar. The cast
/// button was removed while casting is unreliable (its code is kept).
class VideoTopBar extends ConsumerWidget {
  final CinemaPlayerState playerState;
  final PlayerParams params;
  final Channel? channel;
  final bool isLive;

  const VideoTopBar({
    super.key,
    required this.playerState,
    required this.params,
    this.channel,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(localizationsProvider);
    final currentProgram = (isLive && channel != null)
        ? ref.watch(currentProgramProvider(channel!))
        : null;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.surfaceOverlay,
            AppTheme.surfaceOverlay.withValues(alpha: 0),
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          if (isLive) ...[
            if (channel != null) ...[
              ClipRRect(
                borderRadius: AppTheme.radiusMd,
                child: Container(
                  color: AppTheme.borderSubtle,
                  padding: const EdgeInsets.all(3),
                  width: 34,
                  height: 34,
                  child: Image.network(
                    channel!.logo,
                    fit: BoxFit.contain,
                    cacheWidth: 68,
                    cacheHeight: 68,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.tv_rounded,
                      color: AppTheme.textWhite,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          channel?.name ?? playerState.title,
                          style: const TextStyle(
                            color: AppTheme.textWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.favorites.withValues(alpha: 0.2),
                          borderRadius: AppTheme.radiusSm,
                          border: Border.all(
                            color: AppTheme.favorites.withValues(alpha: 0.6),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppTheme.favorites,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.liveTvLive.toUpperCase(),
                              style: const TextStyle(
                                color: AppTheme.favorites,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (currentProgram != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            currentProgram.name,
                            style: const TextStyle(
                              color: AppTheme.textWhite,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currentProgram.timeRange,
                          style: TextStyle(
                            color: AppTheme.textWhite.withValues(alpha: 0.65),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ] else if (channel?.group != null &&
                      channel!.group!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      channel!.group!,
                      style: TextStyle(
                        color: AppTheme.textWhite.withValues(alpha: 0.65),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
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
                  if (params.type == 'tv' &&
                      params.season != null &&
                      params.episode != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${l10n.detailsSeasonNumber(params.season!)}, ${l10n.detailsEpisodeNumber(params.episode!)}${params.episodeTitle != null ? ' - ${params.episodeTitle}' : ''}',
                      style: TextStyle(
                        color: AppTheme.textWhite.withValues(alpha: 0.7),
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
          ],
        ],
      ),
    );
  }
}
