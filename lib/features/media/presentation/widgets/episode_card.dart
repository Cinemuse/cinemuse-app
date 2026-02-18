import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/shared/widgets/hover_scale.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EpisodeCard extends StatefulWidget {
  final Map<String, dynamic> episode;
  final int seasonNumber;
  final Map<String, dynamic> media;
  final bool isWatched;
  final int watchCount;
  final double? resumePercentage;
  final Function(int, int, String)? onEpisodeTap;
  final Function(int, int, DateTime?)? onMarkWatched;
  final Function(int, int) onTrackOptions;
  final List<({int season, int episode})> Function(int, int) onFindMissingPreceding;
  final Function(int, int, List<({int season, int episode})>) onShowMarkPrecedingModal;

  const EpisodeCard({
    super.key,
    required this.episode,
    required this.seasonNumber,
    required this.media,
    required this.isWatched,
    required this.watchCount,
    this.resumePercentage,
    this.onEpisodeTap,
    this.onMarkWatched,
    required this.onTrackOptions,
    required this.onFindMissingPreceding,
    required this.onShowMarkPrecedingModal,
  });

  @override
  State<EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<EpisodeCard> {
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
          onTap: () => widget.onEpisodeTap?.call(widget.seasonNumber, epNumber, name),
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
                              color: AppTheme.primary.withOpacity(0.3),
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
                  child: MarkWatchedButton(
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

class MarkWatchedButton extends StatelessWidget {
  final bool isWatched;
  final int watchCount;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const MarkWatchedButton({
    super.key,
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
