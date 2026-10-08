import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/hero/responsive_action_buttons.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/hero/series_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:cinemuse_app/core/application/display_mode_provider.dart';
import 'package:cinemuse_app/shared/widgets/app_back_button.dart';
import 'package:cinemuse_app/core/constants/tmdb_image_helper.dart';

class DetailsHero extends ConsumerWidget {
  final Map<String, dynamic> media;
  final Map<String, dynamic> details;
  final Map<String, dynamic>? resumeData;
  final VoidCallback onPlayClick;
  final VoidCallback? onRestartClick;
  final double contentPadding;
  final bool isFavorite;
  final bool isInWatchlist;
  final ({bool isFullyWatched, bool isPartiallyWatched, int minWatchCount})?
  seriesWatchStatus;
  final VoidCallback onListTap;
  final VoidCallback? onTrackTap;
  final VoidCallback? onCommentsTap;
  final VoidCallback? onDropClick;
  final VoidCallback? onClearProgress;
  final int? movieWatchCount;

  const DetailsHero({
    super.key,
    required this.media,
    required this.details,
    this.resumeData,
    required this.onPlayClick,
    this.onRestartClick,
    this.onClearProgress,
    this.contentPadding = 24.0,
    this.isFavorite = false,
    this.isInWatchlist = false,
    this.seriesWatchStatus,
    required this.onListTap,
    this.onTrackTap,
    this.onCommentsTap,
    this.onDropClick,
    this.movieWatchCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isWidescreen = ref.watch(isBigPictureProvider);
    final type =
        media['type'] ?? (details['title'] != null ? 'movie' : 'series');
    final titleIt = MediaItem.extractTitleFromTmdb(details, 'it');
    final titleEn =
        MediaItem.extractTitleFromTmdb(details, 'en') ?? media['title'] ?? '';
    final String title = titleEn;
    final tagline = details['tagline'];
    final backdropPath = details['backdrop_path'] ?? media['backdrop_path'];
    final voteAverage = details['vote_average'] as num?;
    final releaseDateStr =
        (details['release_date'] ??
                details['first_air_date'] ??
                media['release_date'] ??
                '')
            .toString();
    final DateTime? releaseDate = DateTime.tryParse(releaseDateStr);
    String formattedDate = '';
    if (releaseDate != null) {
      try {
        formattedDate = DateFormat.yMMMd(
          Localizations.localeOf(context).languageCode,
        ).format(releaseDate);
      } catch (e) {
        // Fallback to default locale if current locale fails
        formattedDate = DateFormat.yMMMd().format(releaseDate);
      }
    }
    final genres = (details['genres'] as List?) ?? [];

    final runtime = type == 'movie'
        ? details['runtime']
        : (details['episode_run_time'] as List?)?.firstOrNull ??
              details['runtime'];

    final mediaItem = MediaItem(
      tmdbId: int.parse(media['id'].toString()),
      mediaType: MediaItem.fromString(type),
      titleIt: titleIt,
      titleEn: titleEn,
      posterPath: details['poster_path'],
      backdropPath: details['backdrop_path'],
      voteAverage: voteAverage?.toDouble(),
      releaseDate: DateTime.tryParse(
        details['release_date'] ?? details['first_air_date'] ?? '',
      ),
      updatedAt: DateTime.now(),
    );

    final heroHeight = isWidescreen
        ? MediaQuery.of(context).size.height * 0.8
        : MediaQuery.of(context).size.height * 0.7;

    return SizedBox(
      height: heroHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Backdrop Image
          if (backdropPath != null &&
              TmdbImageHelper.backdropUrl(context, backdropPath) != null)
            CachedNetworkImage(
              imageUrl: TmdbImageHelper.backdropUrl(context, backdropPath)!,
              fit: BoxFit.cover,
              memCacheWidth: 1280,
            ),

          // Gradients
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  AppTheme.primary,
                  AppTheme.primary,
                  AppTheme.primary.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.05, 0.4, 1.0],
              ),
            ),
          ),

          Positioned(
            bottom: -1,
            left: 0,
            right: 0,
            child: Container(height: 2, color: AppTheme.primary),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppTheme.primary.withValues(alpha: 0.9),
                  AppTheme.primary.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          if (!isWidescreen)
            Positioned(
              top: MediaQuery.of(context).padding.top > 0
                  ? MediaQuery.of(context).padding.top + 16
                  : 24,
              left: contentPadding,
              child: AppBackButton(
                onTap: () => Navigator.of(context).pop(),
                backgroundColor: AppTheme.surfaceOverlay,
              ),
            ),

          // Content
          Padding(
            padding: EdgeInsets.fromLTRB(
              contentPadding,
              0,
              contentPadding,
              isWidescreen ? 16 : 48,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Tagline
                if (tagline != null && tagline.toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text('"$tagline"', style: AppTheme.taglineStyle),
                  ),

                // Title
                Text(title, style: DesktopTypography.heroTitle),
                const SizedBox(height: 16),

                // Metadata Row
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(formattedDate, style: DesktopTypography.captionMeta),
                    if (runtime != null) ...[
                      const _DotSeparator(),
                      Text(
                        type == 'movie'
                            ? '${(runtime / 60).floor()}h ${runtime % 60}m'
                            : l10n.detailsEpisodeRuntime(runtime as int),
                        style: DesktopTypography.captionMeta,
                      ),
                    ],
                    if (voteAverage != null && voteAverage > 0) ...[
                      const _DotSeparator(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: AppTheme.star, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            voteAverage.toStringAsFixed(1),
                            style: DesktopTypography.captionMeta.copyWith(
                              color: AppTheme.textWhite,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),

                // Series Info Row
                if (type == 'series' || type == 'tv') ...[
                  const SizedBox(height: 8),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    children: [
                      Text(
                        l10n.detailsSeasonsCount(
                          details['number_of_seasons'] as int? ?? 0,
                        ),
                        style: TextStyle(
                          color: AppTheme.textWhite.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                      const _DotSeparator(),
                      Text(
                        l10n.detailsEpisodesCount(
                          details['number_of_episodes'] as int? ?? 0,
                        ),
                        style: TextStyle(
                          color: AppTheme.textWhite.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                      if (details['status'] != null) ...[
                        const _DotSeparator(),
                        Text(
                          details['status'] == 'Returning Series'
                              ? l10n.seriesStatusOngoing
                              : details['status'],
                          style: TextStyle(
                            color: _getStatusColor(details['status']),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],

                // Genres
                if (genres.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: genres.map<Widget>((g) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          g['name'],
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 24),

                // Action Buttons (Responsive)
                Focus(
                  canRequestFocus: false,
                  skipTraversal: true,
                  onFocusChange: (hasFocus) {
                    if (hasFocus) {
                      final scrollable = Scrollable.maybeOf(context);
                      if (scrollable != null && scrollable.position.pixels > 0) {
                        scrollable.position.animateTo(
                          0.0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    }
                  },
                  child: ResponsiveActionButtons(
                    onPlayClick: onPlayClick,
                    onRestartClick: onRestartClick,
                    playButtonLabel: _getPlayButtonLabel(l10n, type, resumeData),
                    mediaItem: mediaItem,
                    isFavorite: isFavorite,
                    isInWatchlist: isInWatchlist,
                    onListTap: onListTap,
                    onTrackTap: onTrackTap,
                    onCommentsTap: onCommentsTap,
                    onDropClick: onDropClick,
                    onClearProgress: onClearProgress,
                    seriesWatchStatus: seriesWatchStatus,
                    movieWatchCount: movieWatchCount,
                    hasResumeProgress: (resumeData?['progress'] as int? ?? 0) > 0,
                    mediaId: media['id']?.toString() ?? '',
                    mediaType: type == 'series' ? 'tv' : type,
                    season: resumeData?['season'] as int?,
                    episode: resumeData?['episode'] as int?,
                  ),
                ),

                // Series Progress Bar (extracted)
                if (type == 'series' || type == 'tv')
                  SeriesProgressBar(details: details),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Ended':
        return AppTheme.textMuted;
      case 'Canceled':
        return AppTheme.favorites; // Keep red for canceled
      case 'Returning Series':
        return AppTheme.success; // Keep green for good status
      default:
        return AppTheme.accent;
    }
  }

  String _getPlayButtonLabel(
    AppLocalizations l10n,
    String type,
    Map<String, dynamic>? resumeData,
  ) {
    if (resumeData != null) {
      if (resumeData['type'] == 'tv') {
        // AppLocalizations generates arguments alphabetically: (episode, season)
        final progress = resumeData['progress'] as int? ?? 0;
        final season = resumeData['season'] as int? ?? 1;
        final episode = resumeData['episode'] as int? ?? 1;
        final label = progress > 0
            ? l10n.detailsResumeEpisode(
                episode,
                season,
              )
            : l10n.detailsPlaySeasonEpisode(episode, season);
        return label;
      }
      return l10n.detailsResume;
    }

    // If no resume data, check if it's a series to show "Play S1 E1" (or localized Play)
    if (type == 'series' || type == 'tv') {
      return l10n.detailsPlaySeasonEpisode(1, 1);
    }

    return l10n.detailsPlayNow;
  }
}

class _DotSeparator extends StatelessWidget {
  const _DotSeparator();

  @override
  Widget build(BuildContext context) {
    return Text(
      '•',
      style: TextStyle(
        color: AppTheme.textWhite.withValues(alpha: 0.2),
        fontSize: 16,
      ),
    );
  }
}
