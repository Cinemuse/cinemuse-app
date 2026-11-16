import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/features/media/application/own_reviews_provider.dart';
import 'package:cinemuse_app/features/media/application/play_target.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/own_review.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/hero/responsive_action_buttons.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/hero/series_progress_bar.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:cinemuse_app/shared/widgets/app_back_button.dart';
import 'package:cinemuse_app/shared/widgets/wreath.dart';
import 'package:cinemuse_app/core/constants/tmdb_image_helper.dart';
import 'package:cinemuse_app/features/media/domain/media_details_parts.dart';

class DetailsHero extends ConsumerWidget {
  final MediaItem mediaItem;
  final PlayTarget playTarget;
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
    required this.mediaItem,
    this.playTarget = const PlayTarget(),
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
    final language = ref.watch(settingsProvider.select((s) => s.appLanguage));
    final type = mediaItem.mediaType.name;
    final title = mediaItem.getLocalizedTitle(language) ?? '';
    final tagline = mediaItem.tagline;
    final backdropPath = mediaItem.backdropPath;
    final voteAverage = mediaItem.voteAverage;
    final hasGeneralScore = voteAverage != null && voteAverage > 0;
    final ownReview = ref.watch(
      visibleOwnReviewProvider((
        tmdbId: mediaItem.tmdbId,
        mediaType: mediaItem.mediaType,
      )),
    );
    final releaseDate = mediaItem.releaseDate;

    String formattedDate = '';
    if (releaseDate != null) {
      try {
        formattedDate = DateFormat.yMMMd(
          Localizations.localeOf(context).languageCode,
        ).format(releaseDate);
      } catch (e) {
        formattedDate = DateFormat.yMMMd().format(releaseDate);
      }
    }

    final genres = mediaItem.genreList ?? const <MediaGenre>[];
    final runtime = mediaItem.runtimeMinutes;

    final heroHeight = MediaQuery.sizeOf(context).height * 0.7;
    final isCompact = Breakpoints.isCompact(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final backButtonTop = topInset > 0 ? topInset + 16 : 24.0;

    // At least 70% of the screen, taller when the text needs it: a long
    // title grows the picture instead of running under the back button.
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: heroHeight),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // Backdrop Image
          if (backdropPath != null &&
              TmdbImageHelper.backdropUrl(context, backdropPath) != null)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: TmdbImageHelper.backdropUrl(context, backdropPath)!,
                fit: BoxFit.cover,
                memCacheWidth: 1280,
              ),
            ),

          // Gradients
          Positioned.fill(
            child: Container(
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
          ),

          Positioned(
            bottom: -1,
            left: 0,
            right: 0,
            child: Container(height: 2, color: AppTheme.primary),
          ),
          Positioned.fill(
            child: Container(
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
          ),

          // Content: the only part that sets the height. Its top padding
          // keeps the text below the back button.
          Padding(
            padding: EdgeInsets.fromLTRB(
              contentPadding,
              backButtonTop + AppBackButton.defaultSize + 16,
              contentPadding,
              48,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Tagline
                if (tagline != null && tagline.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text('"$tagline"', style: AppTheme.taglineStyle),
                  ),

                // Title
                Text(
                  title,
                  style: isCompact
                      ? DesktopTypography.heroTitleCompact
                      : DesktopTypography.heroTitle,
                ),
                const SizedBox(height: 16),

                // Metadata Row
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: _withDots([
                    if (formattedDate.isNotEmpty)
                      Text(formattedDate, style: DesktopTypography.captionMeta),
                    if (runtime != null)
                      Text(
                        type == 'movie'
                            ? '${(runtime / 60).floor()}h ${runtime % 60}m'
                            : l10n.detailsEpisodeRuntime(runtime),
                        style: DesktopTypography.captionMeta,
                      ),
                    // One part, so no dot falls between the two scores and
                    // they wrap together.
                    if (hasGeneralScore || ownReview != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasGeneralScore) ...[
                            const Icon(
                              Icons.star,
                              color: AppTheme.star,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              voteAverage.toStringAsFixed(1),
                              style: _scoreStyle,
                            ),
                          ],
                          if (hasGeneralScore && ownReview != null)
                            const SizedBox(width: 12),
                          if (ownReview != null)
                            _OwnScore(rating: ownReview.rating),
                        ],
                      ),
                  ]),
                ),

                // Series Info Row
                if (type == 'series' || type == 'tv')
                  _buildSeriesInfoRow(l10n: l10n),

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
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.08),
                          borderRadius: AppTheme.radius12,
                        ),
                        child: Text(
                          g.name,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
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
                      if (scrollable != null &&
                          scrollable.position.pixels > 0) {
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
                    playButtonLabel: _getPlayButtonLabel(l10n, type),
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
                    hasResumeProgress: playTarget.isResume,
                    mediaId: mediaItem.tmdbId.toString(),
                    mediaType: type == 'series' ? 'tv' : type,
                    season: playTarget.season,
                    episode: playTarget.episode,
                  ),
                ),

                // Series Progress Bar (extracted)
                if (type == 'series' || type == 'tv')
                  SeriesProgressBar(series: mediaItem),
              ],
            ),
          ),

          Positioned(
            top: backButtonTop,
            left: contentPadding,
            child: AppBackButton(
              onTap: () => Navigator.of(context).pop(),
              backgroundColor: AppTheme.surfaceOverlay,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeriesInfoRow({required AppLocalizations l10n}) {
    final numSeasons = mediaItem.numberOfSeasons ?? 0;
    final numEpisodes = mediaItem.numberOfEpisodes ?? 0;
    final statusStr = mediaItem.status;

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        children: _withDots([
          Text(
            l10n.detailsSeasonsCount(numSeasons),
            style: TextStyle(
              color: AppTheme.textWhite.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          Text(
            l10n.detailsEpisodesCount(numEpisodes),
            style: TextStyle(
              color: AppTheme.textWhite.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          if (statusStr != null)
            Text(
              _statusLabel(l10n, statusStr),
              style: TextStyle(
                color: _getStatusColor(statusStr),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
        ]),
      ),
    );
  }

  /// TMDB sends the status in English whatever the language asked for.
  String _statusLabel(AppLocalizations l10n, String status) => switch (status) {
    'Returning Series' => l10n.seriesStatusOngoing,
    'Ended' => l10n.seriesStatusEnded,
    'Canceled' => l10n.seriesStatusCanceled,
    'In Production' => l10n.seriesStatusInProduction,
    'Planned' => l10n.seriesStatusPlanned,
    'Pilot' => l10n.seriesStatusPilot,
    _ => status,
  };

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

  String _getPlayButtonLabel(AppLocalizations l10n, String type) {
    if (type == 'series' || type == 'tv') {
      final season = playTarget.season ?? 1;
      final episode = playTarget.episode ?? 1;
      return playTarget.isResume
          ? l10n.detailsResumeEpisode(season, episode)
          : l10n.detailsPlaySeasonEpisode(season, episode);
    }
    return playTarget.isResume ? l10n.detailsResume : l10n.detailsPlayNow;
  }
}

final _scoreStyle = DesktopTypography.captionMeta.copyWith(
  color: AppTheme.textWhite,
  fontWeight: FontWeight.bold,
);

/// Too small to count leaves: a full wreath beside the number. So a screen
/// reader says the score, not the full wreath.
class _OwnScore extends StatelessWidget {
  final int rating;

  const _OwnScore({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context)!.ownReviewScoreLabel(rating),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Wreath(score: OwnReview.maxRating, size: 20),
            const SizedBox(width: 5),
            Text('$rating', style: _scoreStyle),
          ],
        ),
      ),
    );
  }
}

/// A "•" between the parts that are there, none before the first (REV-219).
List<Widget> _withDots(List<Widget> parts) =>
    parts.expand((p) => [const _DotSeparator(), p]).skip(1).toList();

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
