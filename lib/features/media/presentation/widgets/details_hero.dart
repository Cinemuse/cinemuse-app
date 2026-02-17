import 'package:cinemuse_app/features/media/presentation/widgets/series_progress_bar.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/social_actions_group.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cinemuse_app/shared/widgets/hover_scale.dart';
import 'package:cinemuse_app/shared/widgets/app_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DetailsHero extends ConsumerWidget {
  final Map<String, dynamic> media;
  final Map<String, dynamic> details;
  final Map<String, dynamic>? resumeData;
  final VoidCallback onPlayClick;
  final Function(Map<String, dynamic>) onDeepSearch;
  final double contentPadding;
  final bool isFavorite;
  final bool isInWatchlist;
  final ({bool isFullyWatched, bool isPartiallyWatched, int minWatchCount})? seriesWatchStatus;
  final VoidCallback onListTap;
  final VoidCallback? onTrackTap;

  const DetailsHero({
    super.key,
    required this.media,
    required this.details,
    this.resumeData,
    required this.onPlayClick,
    required this.onDeepSearch,
    this.contentPadding = 24.0,
    this.isFavorite = false,
    this.isInWatchlist = false,
    this.seriesWatchStatus,
    required this.onListTap,
    this.onTrackTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final type = media['type'] ?? (details['title'] != null ? 'movie' : 'series');
    final title = details['title'] ?? details['name'] ?? media['title'] ?? '';
    final tagline = details['tagline'];
    final backdropPath = details['backdrop_path'] ?? media['backdrop_path'];
    final voteAverage = details['vote_average'] as num?;
    final year = (details['release_date'] ?? details['first_air_date'] ?? media['release_date'] ?? '')
        .toString()
        .split('-')
        .first;
    final genres = (details['genres'] as List?) ?? [];
    
    final runtime = type == 'movie'
        ? details['runtime']
        : (details['episode_run_time'] as List?)?.firstOrNull ?? details['runtime'];

    final mediaItem = MediaItem(
      tmdbId: int.parse(media['id'].toString()),
      mediaType: MediaItem.fromString(type),
      title: title,
      posterPath: details['poster_path'],
      backdropPath: details['backdrop_path'],
      voteAverage: voteAverage?.toDouble(),
      releaseDate: DateTime.tryParse(details['release_date'] ?? details['first_air_date'] ?? ''),
      updatedAt: DateTime.now(),
    );

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Backdrop Image
          if (backdropPath != null)
            Image.network(
              'https://image.tmdb.org/t/p/original$backdropPath',
              fit: BoxFit.cover,
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
                  AppTheme.primary.withOpacity(0.3),
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
            child: Container(
              height: 2,
              color: AppTheme.primary,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppTheme.primary.withOpacity(0.9),
                  AppTheme.primary.withOpacity(0.2),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.fromLTRB(contentPadding, 0, contentPadding, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Back Button
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: AppBackButton(
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),

                // Tagline
                if (tagline != null && tagline.toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      '"$tagline"',
                      style: GoogleFonts.lora(
                        color: AppTheme.accent,
                        fontStyle: FontStyle.italic,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                // Title
                Text(
                  title,
                  style: DesktopTypography.heroTitle,
                ),
                const SizedBox(height: 16),

                // Metadata Row
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(
                      year,
                      style: DesktopTypography.captionMeta,
                    ),
                    if (runtime != null) ...[
                      const _DotSeparator(),
                      Text(
                        type == 'movie'
                            ? '${(runtime / 60).floor()}h ${runtime % 60}m'
                            : '${runtime}m/ep',
                        style: DesktopTypography.captionMeta,
                      ),
                    ],
                    if (voteAverage != null && voteAverage > 0) ...[
                      const _DotSeparator(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
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
                        '${details['number_of_seasons']} ${l10n.detailsSeasonLabel}${details['number_of_seasons'] != 1 ? 's' : ''}',
                        style: TextStyle(color: AppTheme.textWhite.withOpacity(0.6), fontSize: 13),
                      ),
                      const _DotSeparator(),
                      Text(
                        '${details['number_of_episodes']} ${l10n.detailsEpisodes}',
                        style: TextStyle(color: AppTheme.textWhite.withOpacity(0.6), fontSize: 13),
                      ),
                      if (details['status'] != null) ...[
                        const _DotSeparator(),
                        Text(
                          details['status'] == 'Returning Series' ? 'Ongoing' : details['status'],
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
                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => onDeepSearch({'type': 'genre', 'id': g['id'], 'name': g['name']}),
                          child: HoverScale(
                            scale: 1.1,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                g['name'],
                                style: TextStyle(
                                  color: AppTheme.textWhite.withOpacity(0.6),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    // Play Button
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onPlayClick,
                        child: HoverScale(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15),
                            decoration: BoxDecoration(
                              color: AppTheme.accent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(color: AppTheme.accent.withOpacity(0.4), blurRadius: 25, offset: const Offset(0, 8)),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.play_arrow_outlined, color: AppTheme.textWhite, size: 24),
                                const SizedBox(width: 12),
                                Text(
                                  _getPlayButtonLabel(l10n, type, resumeData),
                                  style: const TextStyle(color: AppTheme.textWhite, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Social Actions (extracted)
                    SocialActionsGroup(
                      mediaItem: mediaItem,
                      isFavorite: isFavorite,
                      isInWatchlist: isInWatchlist,
                      onListTap: onListTap,
                    ),
                    const SizedBox(width: 16),

                    // Track Button
                    if (onTrackTap != null)
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onTrackTap,
                          child: HoverScale(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                              decoration: BoxDecoration(
                                color: (seriesWatchStatus?.isFullyWatched ?? false)
                                    ? Colors.green.withOpacity(0.15)
                                    : AppTheme.textWhite.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: (seriesWatchStatus?.isFullyWatched ?? false)
                                      ? Colors.green.withOpacity(0.3)
                                      : AppTheme.textWhite.withOpacity(0.05)
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    seriesWatchStatus?.isFullyWatched ?? false 
                                        ? Icons.check_circle 
                                        : (seriesWatchStatus?.isPartiallyWatched ?? false ? Icons.check_circle_outline : Icons.add_task),
                                    color: (seriesWatchStatus?.isFullyWatched ?? false)
                                        ? Colors.green
                                        : AppTheme.textWhite,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    seriesWatchStatus?.isFullyWatched ?? false 
                                        ? (seriesWatchStatus!.minWatchCount > 1 ? 'Watched x${seriesWatchStatus!.minWatchCount}' : 'Watched')
                                        : (seriesWatchStatus?.isPartiallyWatched ?? false ? 'Finish Series' : 'Track'),
                                    style: TextStyle(
                                      color: (seriesWatchStatus?.isFullyWatched ?? false)
                                          ? Colors.green
                                          : AppTheme.textWhite, 
                                      fontSize: 16, 
                                      fontWeight: FontWeight.bold
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
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
        return Colors.redAccent; // Keep red for canceled
      case 'Returning Series':
        return Colors.greenAccent; // Keep green for good status
      default:
        return AppTheme.accent;
    }
  }

  String _getPlayButtonLabel(AppLocalizations l10n, String type, Map<String, dynamic>? resumeData) {
    if (resumeData != null) {
      if (resumeData['type'] == 'tv') {
        // AppLocalizations generates arguments alphabetically: (episode, season)
        final progress = resumeData['progress'] as int? ?? 0;
        final label = progress > 0 
           ? l10n.detailsResumeEpisode(resumeData['episode'], resumeData['season'])
           : "${l10n.detailsPlay} S${resumeData['season']} E${resumeData['episode']}";
        return label;
      }
      return l10n.detailsResume;
    }
    
    // If no resume data, check if it's a series to show "Play S1 E1" (or localized Play)
    if (type == 'series' || type == 'tv') {
       return "${l10n.detailsPlay} S1 E1";
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
      style: TextStyle(color: AppTheme.textWhite.withOpacity(0.2), fontSize: 16),
    );
  }
}
