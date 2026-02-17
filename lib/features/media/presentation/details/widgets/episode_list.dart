import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/hover_scale.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';

class EpisodeList extends StatelessWidget {
  final List<dynamic> episodes;
  final int seasonNumber;
  final Map<String, dynamic> media;
  final Map<String, dynamic>? watchedData;
  final Map<String, int>? watchedEpisodesCount;
  final Map<String, WatchHistory>? episodeProgress;
  final Function(int season, int episode)? onEpisodeTap;
  final Function(int season, int episode, DateTime? date)? onMarkWatched;
  final Function(List<({int season, int episode})> episodes)? onMarkMultipleWatched;
  final Function(int season, int episode)? onRemoveWatch;
  final Function(int season, int episode)? onRemoveAllWatch;

  const EpisodeList({
    super.key,
    required this.episodes,
    required this.seasonNumber,
    required this.media,
    this.watchedData,
    this.watchedEpisodesCount,
    this.episodeProgress,
    this.onEpisodeTap,
    this.onMarkWatched,
    this.onMarkMultipleWatched,
    this.onRemoveWatch,
    this.onRemoveAllWatch,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: episodes.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final episode = episodes[index];
        final epNumber = episode['episode_number'];
        
        // Watched status from all logs
        final watchCount = watchedEpisodesCount?['$seasonNumber-$epNumber'] ?? 0;
        final bool isWatched = watchCount > 0;
        
        // Progress from periodic watch history (Resume bars)
        double? resumePercentage;
        
        // 1. Try specific episode progress (for every episode)
        final epKey = '$seasonNumber-$epNumber';
        if (episodeProgress != null && episodeProgress!.containsKey(epKey)) {
          final history = episodeProgress![epKey]!;
          if (history.status == WatchStatus.watching && history.totalDuration != null && history.totalDuration! > 0) {
            resumePercentage = history.progressSeconds / history.totalDuration!;
          }
        }
        
        // 2. Fallback to global series progress if it matches this episode
        if (resumePercentage == null && watchedData != null) {
          final lastSeason = watchedData!['season'] as int?;
          final lastEpisode = watchedData!['episode'] as int?;
          
          if (lastSeason == seasonNumber && lastEpisode == epNumber) {
            final progress = watchedData!['progress_seconds'] as int? ?? 0;
            final total = watchedData!['total_duration'] as int? ?? 0;
            if (total > 0) {
              resumePercentage = progress / total;
            }
          }
        }

        return _EpisodeCard(
          episode: episode,
          seasonNumber: seasonNumber,
          media: media,
          isWatched: isWatched,
          watchCount: watchCount,
          resumePercentage: resumePercentage,
          onEpisodeTap: onEpisodeTap,
          onMarkWatched: onMarkWatched,
          onRemoveWatch: onRemoveWatch,
          onRemoveAllWatch: onRemoveAllWatch,
          onTrackOptions: (s, e) => _showTrackOptions(context, s, e),
          onFindMissingPreceding: _findMissingPreceding,
          onShowMarkPrecedingModal: (s, e, m) => _showMarkPrecedingModal(context, s, e, m),
          onMarkMultipleWatched: onMarkMultipleWatched,
        );
      },
    );
  }

  List<({int season, int episode})> _findMissingPreceding(int currentSeason, int currentEpisode) {
    final List<({int season, int episode})> missing = [];
    final seasons = media['seasons'] as List? ?? [];
    
    for (final season in seasons) {
      final sNum = season['season_number'] as int? ?? 0;
      if (sNum == 0) continue; // Skip specials
      if (sNum > currentSeason) break;
      
      final epCount = season['episode_count'] as int? ?? 0;
      final maxE = (sNum == currentSeason) ? currentEpisode - 1 : epCount;
      
      for (int e = 1; e <= maxE; e++) {
        final key = '$sNum-$e';
        if ((watchedEpisodesCount?[key] ?? 0) == 0) {
          missing.add((season: sNum, episode: e));
        }
      }
    }
    return missing;
  }

  void _showMarkPrecedingModal(BuildContext context, int season, int episode, List<({int season, int episode})> missing) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.secondary,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mark previous?', style: TextStyle(color: Colors.white)),
        content: Text(
          'You marked Episode $episode. Do you also want to mark the ${missing.length} previous unwatched episode(s) as watched?',
          style: const TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onMarkWatched?.call(season, episode, null);
            },
            child: const Text('Only this one', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final allToMark = [...missing, (season: season, episode: episode)];
              onMarkMultipleWatched?.call(allToMark);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Mark all'),
          ),
        ],
      ),
    );
  }

  void _showTrackOptions(BuildContext context, int season, int episode) {
    showDialog(
      context: context,
      builder: (context) => _TrackOptionsModal(
        season: season,
        episode: episode,
        onRewatch: (date) => onMarkWatched?.call(season, episode, date),
        onRemoveOne: () => onRemoveWatch?.call(season, episode),
        onRemoveAll: () => onRemoveAllWatch?.call(season, episode),
      ),
    );
  }
}

class _EpisodeCard extends StatefulWidget {
  final Map<String, dynamic> episode;
  final int seasonNumber;
  final Map<String, dynamic> media;
  final bool isWatched;
  final int watchCount;
  final double? resumePercentage;
  final Function(int, int)? onEpisodeTap;
  final Function(int, int, DateTime?)? onMarkWatched;
  final Function(int, int)? onRemoveWatch;
  final Function(int, int)? onRemoveAllWatch;
  final Function(int, int) onTrackOptions;
  final List<({int season, int episode})> Function(int, int) onFindMissingPreceding;
  final Function(int, int, List<({int season, int episode})>) onShowMarkPrecedingModal;
  final Function(List<({int season, int episode})>)? onMarkMultipleWatched;

  const _EpisodeCard({
    required this.episode,
    required this.seasonNumber,
    required this.media,
    required this.isWatched,
    required this.watchCount,
    this.resumePercentage,
    this.onEpisodeTap,
    this.onMarkWatched,
    this.onRemoveWatch,
    this.onRemoveAllWatch,
    required this.onTrackOptions,
    required this.onFindMissingPreceding,
    required this.onShowMarkPrecedingModal,
    this.onMarkMultipleWatched,
  });

  @override
  State<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<_EpisodeCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final epNumber = widget.episode['episode_number'];
    final name = widget.episode['name'] ?? 'Episode $epNumber';
    final overview = widget.episode['overview'] ?? '';
    final stillPath = widget.episode['still_path'];
    final runtime = widget.episode['runtime'];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.secondary.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.textWhite.withOpacity(0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onEpisodeTap?.call(widget.seasonNumber, epNumber),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 12),
                // Episode Still
                SizedBox(
                  width: 160,
                  child: Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.secondary,
                            borderRadius: BorderRadius.circular(8),
                            image: stillPath != null
                                ? DecorationImage(
                                    image: NetworkImage('https://image.tmdb.org/t/p/w300$stillPath'),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: stillPath == null
                              ? const Center(child: Icon(Icons.tv, color: AppTheme.textMuted, size: 32))
                              : null,
                        ),
                      ),
                      
                      // Play Overlay
                      Positioned.fill(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow, color: AppTheme.textWhite, size: 24),
                          ),
                        ),
                      ),

                      // Episode Number
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.textWhite.withOpacity(0.1)),
                          ),
                          child: Text(
                            'EP $epNumber',
                            style: GoogleFonts.firaCode(
                              color: AppTheme.textWhite,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      // Runtime
                      if (runtime != null)
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, color: AppTheme.textWhite, size: 9),
                                const SizedBox(width: 3),
                                Text(
                                  '${runtime}m',
                                  style: const TextStyle(color: AppTheme.textWhite, fontSize: 9),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Progress Bar
                      if (!widget.isWatched && widget.resumePercentage != null && widget.resumePercentage! > 0)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: AppTheme.textWhite.withOpacity(0.1),
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                            ),
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: widget.resumePercentage!.clamp(0.0, 1.0),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: AppTheme.accent,
                                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: DesktopTypography.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      
                      // Expandable Overview
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final textSpan = TextSpan(
                            text: overview,
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          );

                          final textPainter = TextPainter(
                            text: textSpan,
                            maxLines: 2,
                            textDirection: TextDirection.ltr,
                          )..layout(maxWidth: constraints.maxWidth);

                          final isOverflowing = textPainter.didExceedMaxLines;

                          return AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            alignment: Alignment.topCenter,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  overview,
                                  style: TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                  maxLines: _isExpanded ? null : 2,
                                  overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                                ),
                                if (isOverflowing)
                                  GestureDetector(
                                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        _isExpanded ? 'Show less' : 'Read more',
                                        style: const TextStyle(
                                          color: AppTheme.accent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                
                // Mark Watched Button
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _MarkWatchedButton(
                    isWatched: widget.isWatched,
                    watchCount: widget.watchCount,
                    onTap: () {
                      if (widget.isWatched) {
                        widget.onTrackOptions(widget.seasonNumber, epNumber);
                      } else {
                        final missing = widget.onFindMissingPreceding(widget.seasonNumber, epNumber);
                        if (missing.isNotEmpty) {
                          widget.onShowMarkPrecedingModal(widget.seasonNumber, epNumber, missing);
                        } else {
                          widget.onMarkWatched?.call(widget.seasonNumber, epNumber, null);
                        }
                      }
                    },
                    onLongPress: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppTheme.accent,
                                onPrimary: Colors.white,
                                surface: AppTheme.secondary,
                                onSurface: Colors.white,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (date != null) {
                        widget.onMarkWatched?.call(widget.seasonNumber, epNumber, date);
                      }
                    },
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

class _TrackOptionsModal extends StatefulWidget {
  final int season;
  final int episode;
  final Function(DateTime? date) onRewatch;
  final VoidCallback onRemoveOne;
  final VoidCallback onRemoveAll;

  const _TrackOptionsModal({
    required this.season,
    required this.episode,
    required this.onRewatch,
    required this.onRemoveOne,
    required this.onRemoveAll,
  });

  @override
  State<_TrackOptionsModal> createState() => _TrackOptionsModalState();
}

class _TrackOptionsModalState extends State<_TrackOptionsModal> {
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.secondary,
      surfaceTintColor: Colors.transparent,
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.history, color: AppTheme.accent, size: 24),
          const SizedBox(width: 12),
          Text('Episode ${widget.episode}', style: const TextStyle(color: Colors.white, fontSize: 20)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Track your progress for this episode.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 24),
          
          // Rewatch Button with Date picker
          _ModalButton(
            icon: Icons.replay,
            label: 'Mark a Rewatch',
            subtitle: _selectedDate == null ? 'Today' : 'Watched on ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
            color: AppTheme.accent,
            onTap: () {
              Navigator.pop(context);
              widget.onRewatch(_selectedDate);
            },
            onSecondaryTap: () async {
              final date = await _selectDate(context);
              if (date != null) {
                setState(() => _selectedDate = date);
              }
            },
          ),
          
          const SizedBox(height: 12),
          
          // Remove One
          _ModalButton(
            icon: Icons.remove_circle_outline,
            label: 'Remove One Watch',
            subtitle: 'Delete the latest entry',
            color: Colors.orangeAccent,
            onTap: () {
              Navigator.pop(context);
              widget.onRemoveOne();
            },
          ),
          
          const SizedBox(height: 12),
          
          // Remove All
          _ModalButton(
            icon: Icons.delete_outline,
            label: 'Remove All History',
            subtitle: 'Clear all logs for this episode',
            color: Colors.redAccent,
            onTap: () {
              Navigator.pop(context);
              widget.onRemoveAll();
            },
          ),
        ],
      ),
    );
  }

  Future<DateTime?> _selectDate(BuildContext context) async {
    return await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.accent,
              onPrimary: Colors.white,
              surface: AppTheme.secondary,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
  }
}

class _ModalButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onSecondaryTap;

  const _ModalButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: color.withOpacity(0.7), fontSize: 11),
                  ),
                ],
              ),
            ),
            if (onSecondaryTap != null)
              IconButton(
                icon: const Icon(Icons.calendar_today, size: 18),
                color: color,
                onPressed: onSecondaryTap,
                tooltip: 'Pick Date',
              ),
          ],
        ),
      ),
    );
  }
}

class _MarkWatchedButton extends StatelessWidget {
  final bool isWatched;
  final int watchCount;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _MarkWatchedButton({
    required this.isWatched,
    this.watchCount = 0,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isWatched ? 'Watched' : 'Mark as Watched (Long press for date)',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: HoverScale(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: watchCount > 1 ? 12 : 8, 
                vertical: 8
              ),
              decoration: BoxDecoration(
                color: isWatched 
                    ? Colors.green 
                    : AppTheme.textWhite.withOpacity(0.05),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isWatched 
                      ? Colors.green 
                      : AppTheme.textWhite.withOpacity(0.1),
                ),
              ),
              child: watchCount > 1
                  ? Text(
                      'x$watchCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : Icon(
                      isWatched ? Icons.check : Icons.remove_red_eye_outlined,
                      color: isWatched ? Colors.white : AppTheme.textMuted,
                      size: 20,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
