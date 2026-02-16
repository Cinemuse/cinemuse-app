import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/hover_scale.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

class EpisodeList extends StatelessWidget {
  final List<dynamic> episodes;
  final int seasonNumber;
  final Map<String, dynamic> media;
  final Map<String, dynamic>? watchedData;
  final Function(int season, int episode)? onEpisodeTap;

  const EpisodeList({
    super.key,
    required this.episodes,
    required this.seasonNumber,
    required this.media,
    this.watchedData,
    this.onEpisodeTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: episodes.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final episode = episodes[index];
        final epNumber = episode['episode_number'];
        final name = episode['name'] ?? 'Episode $epNumber';
        final overview = episode['overview'] ?? '';
        final stillPath = episode['still_path'];
        final runtime = episode['runtime'];

        // Check if watched
        bool isWatched = false;
        double? resumePercentage;
        if (watchedData != null && watchedData!['s'] != null) {
          final seasons = watchedData!['s'] as Map;
          if (seasons[seasonNumber.toString()] != null) {
            final episodesMap = seasons[seasonNumber.toString()] as Map;
            if (episodesMap[epNumber.toString()] != null) {
              final epData = episodesMap[epNumber.toString()];
              if (epData is Map) {
                if (epData['c'] == true) {
                  isWatched = true;
                } else if (epData['p'] != null) {
                  resumePercentage = (epData['p'] as num).toDouble() / 100;
                }
              }
            }
          }
        }

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => onEpisodeTap?.call(seasonNumber, epNumber),
            child: HoverScale(
              scale: 1.02,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.textWhite.withOpacity(0.05)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    // Episode Still
                    Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Container(
                            width: 140,
                            decoration: BoxDecoration(
                              color: AppTheme.secondary,
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
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.play_arrow, color: AppTheme.textWhite, size: 32),
                            ),
                          ),
                        ),

                        // Episode Number
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.textWhite.withOpacity(0.1)),
                            ),
                            child: Text(
                              'EP $epNumber',
                              style: GoogleFonts.firaCode(
                                color: AppTheme.textWhite,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        // Watched Badge
                        if (isWatched)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, color: AppTheme.textWhite, size: 12),
                            ),
                          ),

                        // Runtime
                        if (runtime != null)
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time, color: AppTheme.textWhite, size: 10),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${runtime}m',
                                    style: const TextStyle(color: AppTheme.textWhite, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Progress Bar
                        if (!isWatched && resumePercentage != null && resumePercentage! > 0)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: AppTheme.textWhite.withOpacity(0.1),
                              ),
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: resumePercentage!.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: AppTheme.accent,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
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
                          Text(
                            overview,
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
