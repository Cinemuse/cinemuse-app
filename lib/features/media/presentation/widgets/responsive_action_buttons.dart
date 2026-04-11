import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/social_actions_group.dart';
import 'package:cinemuse_app/shared/widgets/hover_scale.dart';
import 'package:flutter/material.dart';

class ResponsiveActionButtons extends StatelessWidget {
  final VoidCallback onPlayClick;
  final String playButtonLabel;
  final MediaItem mediaItem;
  final bool isFavorite;
  final bool isInWatchlist;
  final VoidCallback onListTap;
  final VoidCallback? onTrackTap;
  final ({bool isFullyWatched, bool isPartiallyWatched, int minWatchCount})? seriesWatchStatus;
  final int? movieWatchCount;
  final double mobileBreakpoint;

  const ResponsiveActionButtons({
    super.key,
    required this.onPlayClick,
    required this.playButtonLabel,
    required this.mediaItem,
    required this.isFavorite,
    required this.isInWatchlist,
    required this.onListTap,
    this.onTrackTap,
    this.seriesWatchStatus,
    this.movieWatchCount,
    this.mobileBreakpoint = 600.0,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < mobileBreakpoint;

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PlayButton(onPlayClick: onPlayClick, label: playButtonLabel, isFullWidth: true),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SocialActionsGroup(
                  mediaItem: mediaItem,
                  isFavorite: isFavorite,
                  isInWatchlist: isInWatchlist,
                  onListTap: onListTap,
                ),
              ),
              if (onTrackTap != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _TrackButton(
                    onTrackTap: onTrackTap!,
                    seriesWatchStatus: seriesWatchStatus,
                    movieWatchCount: movieWatchCount,
                  ),
                ),
              ],
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        _PlayButton(onPlayClick: onPlayClick, label: playButtonLabel),
        const SizedBox(width: 16),
        SocialActionsGroup(
          mediaItem: mediaItem,
          isFavorite: isFavorite,
          isInWatchlist: isInWatchlist,
          onListTap: onListTap,
        ),
        if (onTrackTap != null) ...[
          const SizedBox(width: 16),
          _TrackButton(
            onTrackTap: onTrackTap!,
            seriesWatchStatus: seriesWatchStatus,
            movieWatchCount: movieWatchCount,
          ),
        ],
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  final VoidCallback onPlayClick;
  final String label;
  final bool isFullWidth;

  const _PlayButton({
    required this.onPlayClick,
    required this.label,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPlayClick,
        child: HoverScale(
          child: Container(
            width: isFullWidth ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15),
            decoration: BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: AppTheme.accent.withOpacity(0.4), blurRadius: 25, offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
              children: [
                const Icon(Icons.play_arrow_outlined, color: AppTheme.textWhite, size: 24),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(color: AppTheme.textWhite, fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackButton extends StatelessWidget {
  final VoidCallback onTrackTap;
  final ({bool isFullyWatched, bool isPartiallyWatched, int minWatchCount})? seriesWatchStatus;
  final int? movieWatchCount;

  const _TrackButton({
    required this.onTrackTap,
    this.seriesWatchStatus,
    this.movieWatchCount,
  });

  @override
  Widget build(BuildContext context) {
    final isMovie = movieWatchCount != null;
    final isFullyWatched = seriesWatchStatus?.isFullyWatched ?? (isMovie && movieWatchCount! > 0);
    final isPartiallyWatched = seriesWatchStatus?.isPartiallyWatched ?? false;
    final minWatchCount = seriesWatchStatus?.minWatchCount ?? (movieWatchCount ?? 0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTrackTap,
        child: HoverScale(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
            decoration: BoxDecoration(
              color: isFullyWatched
                  ? Colors.green.withOpacity(0.15)
                  : AppTheme.textWhite.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isFullyWatched
                    ? Colors.green.withOpacity(0.3)
                    : AppTheme.textWhite.withOpacity(0.05)
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isFullyWatched 
                      ? Icons.check_circle 
                      : (isPartiallyWatched ? Icons.check_circle_outline : Icons.add_task),
                  color: isFullyWatched
                      ? Colors.green
                      : AppTheme.textWhite,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    isFullyWatched 
                        ? (isMovie 
                            ? (minWatchCount > 1 ? 'Watched x$minWatchCount' : 'Watched') 
                            : (minWatchCount > 1 ? 'Up to date x$minWatchCount' : 'Up to date'))
                        : (isPartiallyWatched ? 'Finish Series' : 'Track'),
                    style: TextStyle(
                      color: isFullyWatched
                          ? Colors.green
                          : AppTheme.textWhite, 
                      fontSize: 16, 
                      fontWeight: FontWeight.bold
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
