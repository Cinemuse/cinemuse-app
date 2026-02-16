import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cinemuse_app/shared/widgets/hover_scale.dart';
import 'package:cinemuse_app/shared/widgets/app_back_button.dart';

class DetailsHero extends StatelessWidget {
  final Map<String, dynamic> media;
  final Map<String, dynamic> details;
  final Map<String, dynamic>? resumeData;
  final Map<String, dynamic>? watchedData;
  final VoidCallback onPlayClick;
  final Function(Map<String, dynamic>) onDeepSearch;
  final double contentPadding;
  final bool isFavorite;
  final bool isInWatchlist;
  final VoidCallback onHeartTap;
  final VoidCallback onBookmarkTap;
  final VoidCallback onListTap;

  const DetailsHero({
    super.key,
    required this.media,
    required this.details,
    this.resumeData,
    this.watchedData,
    required this.onPlayClick,
    required this.onDeepSearch,
    this.contentPadding = 24.0,
    this.isFavorite = false,
    this.isInWatchlist = false,
    required this.onHeartTap,
    required this.onBookmarkTap,
    required this.onListTap,
  });

  @override
  Widget build(BuildContext context) {
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

    return Container(
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
                  AppTheme.primary, // Reinforced solid bottom
                  AppTheme.primary.withOpacity(0.3),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.05, 0.4, 1.0],
              ),
            ),
          ),
          
          // Bottom Seal (prevents hairline backdrop leaks during scrolling)
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
                        '${details['number_of_episodes']} Episodes',
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
                                  resumeData != null
                                      ? (resumeData!['type'] == 'tv'
                                          ? l10n.detailsResumeEpisode(resumeData!['season'], resumeData!['episode'])
                                          : l10n.detailsResume)
                                      : l10n.detailsPlayNow,
                                  style: const TextStyle(color: AppTheme.textWhite, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Social Group
                    _SocialGroup(
                      isFavorite: isFavorite,
                      isInWatchlist: isInWatchlist,
                      onHeartTap: onHeartTap,
                      onBookmarkTap: onBookmarkTap,
                      onListTap: onListTap,
                    ),
                    const SizedBox(width: 16),

                    // Track Button
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {},
                        child: HoverScale(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                            decoration: BoxDecoration(
                              color: AppTheme.textWhite.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.textWhite.withOpacity(0.05)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.tv_outlined, color: AppTheme.textWhite, size: 24),
                                SizedBox(width: 12),
                                Text(
                                  'Track',
                                  style: TextStyle(color: AppTheme.textWhite, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Series Progress Bar
                if (type == 'series' || type == 'tv') 
                   _SeriesProgressBar(details: details, watchedData: watchedData),
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
        return Colors.grey;
      case 'Canceled':
        return Colors.redAccent;
      case 'Returning Series':
        return Colors.greenAccent;
      default:
        return Colors.blueAccent;
    }
  }
}

class _MetadataLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _MetadataLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: GoogleFonts.firaCode(
          color: AppTheme.textWhite.withAlpha(204), // 0.8 opacity
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
    );
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

class _SocialGroup extends StatelessWidget {
  final bool isFavorite;
  final bool isInWatchlist;
  final VoidCallback onHeartTap;
  final VoidCallback onBookmarkTap;
  final VoidCallback onListTap;

  const _SocialGroup({
    required this.isFavorite,
    required this.isInWatchlist,
    required this.onHeartTap,
    required this.onBookmarkTap,
    required this.onListTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.textWhite.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.textWhite.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SocialIcon(
            icon: isFavorite ? Icons.favorite : Icons.favorite_border, 
            color: isFavorite ? AppTheme.favorites : AppTheme.textWhite,
            onTap: onHeartTap
          ),
          _VerticalDivider(),
          _SocialIcon(
            icon: isInWatchlist ? Icons.bookmark : Icons.bookmark_border, 
            color: isInWatchlist ? AppTheme.watchlist : AppTheme.textWhite,
            onTap: onBookmarkTap
          ),
          _VerticalDivider(),
          _SocialIcon(
            icon: Icons.format_list_bulleted, 
            onTap: onListTap, 
            showArrow: true
          ),
        ],
      ),
    );
  }
}

class _SocialIcon extends StatefulWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  final bool showArrow;

  const _SocialIcon({
    super.key,
    required this.icon, 
    this.color,
    required this.onTap, 
    this.showArrow = false
  });

  @override
  State<_SocialIcon> createState() => _SocialIconState();
}

class _SocialIconState extends State<_SocialIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool? _isOptimisticActive;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(_SocialIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset optimistic state when the actual data arrives from the parent
    if (oldWidget.icon != widget.icon || oldWidget.color != widget.color) {
      _isOptimisticActive = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Derive the current state (either optimistic or from parent)
  bool get isActive => _isOptimisticActive ?? (widget.color != null && widget.color != AppTheme.textWhite);

  @override
  Widget build(BuildContext context) {
    // Determine effective icon based on active state
    IconData effectiveIcon = widget.icon;
    if (_isOptimisticActive != null) {
      if (widget.icon == Icons.favorite || widget.icon == Icons.favorite_border) {
        effectiveIcon = _isOptimisticActive! ? Icons.favorite : Icons.favorite_border;
      } else if (widget.icon == Icons.bookmark || widget.icon == Icons.bookmark_border) {
        effectiveIcon = _isOptimisticActive! ? Icons.bookmark : Icons.bookmark_border;
      }
    }

    // Determine effective color
    Color effectiveColor = widget.color ?? AppTheme.textWhite;
    if (_isOptimisticActive != null) {
      if (widget.icon == Icons.favorite || widget.icon == Icons.favorite_border) {
        effectiveColor = _isOptimisticActive! ? AppTheme.favorites : AppTheme.textWhite;
      } else if (widget.icon == Icons.bookmark || widget.icon == Icons.bookmark_border) {
        effectiveColor = _isOptimisticActive! ? AppTheme.watchlist : AppTheme.textWhite;
      }
    }

    return HoverScale(
      scale: 1.2,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            // Only toggle for heart/bookmark
            if (widget.icon != Icons.format_list_bulleted) {
              setState(() {
                _isOptimisticActive = !isActive;
              });
            }
            _controller.forward(from: 0.0);
            widget.onTap();
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: widget.showArrow ? 12 : 18, vertical: 15),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                    child: Icon(
                      effectiveIcon, 
                      key: ValueKey(effectiveIcon),
                      color: effectiveColor, 
                      size: 24
                    ),
                  ),
                ),
                if (widget.showArrow) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down, color: (effectiveColor).withOpacity(0.5), size: 14),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      width: 1,
      color: AppTheme.textWhite.withOpacity(0.1),
    );
  }
}

class _SeriesProgressBar extends StatelessWidget {
  final Map<String, dynamic> details;
  final Map<String, dynamic>? watchedData;

  const _SeriesProgressBar({required this.details, this.watchedData});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final progress = _calculateProgress();
    if (progress == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.detailsSeriesProgress.toUpperCase(),
                style: GoogleFonts.firaCode(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '${progress.percentage}% (${progress.watchedCount}/${progress.totalCount})',
                style: GoogleFonts.firaCode(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress.percentage / 100,
              backgroundColor: AppTheme.textWhite.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  ({int percentage, int watchedCount, int totalCount})? _calculateProgress() {
    final seasons = details['seasons'] as List?;
    if (seasons == null) return null;

    int totalEpisodes = 0;
    int watchedEpisodesCount = 0;

    final now = DateTime.now();
    final lastAired = details['last_episode_to_air'];

    for (var season in seasons) {
      if (season['season_number'] > 0 && season['episode_count'] != null) {
        if (season['air_date'] == null) continue;
        final airDate = DateTime.tryParse(season['air_date']);
        if (airDate == null || airDate.isAfter(now)) continue;

        if (lastAired != null && season['season_number'] == lastAired['season_number']) {
          totalEpisodes += (lastAired['episode_number'] as int);
        } else if (lastAired == null || (season['season_number'] as int) < (lastAired['season_number'] as int)) {
          totalEpisodes += (season['episode_count'] as int);
        }
      }
    }

    if (watchedData != null && watchedData!['s'] != null) {
      final watchedSeasons = watchedData!['s'] as Map;
      for (var seasonValue in watchedSeasons.values) {
        if (seasonValue is Map) {
          final episodes = seasonValue.keys.where((k) => k != 'c').toList();
          watchedEpisodesCount += episodes.length;
        }
      }
    }

    if (totalEpisodes == 0) return null;

    return (
      percentage: ((watchedEpisodesCount / totalEpisodes) * 100).round().clamp(0, 100),
      watchedCount: watchedEpisodesCount,
      totalCount: totalEpisodes,
    );
  }
}
