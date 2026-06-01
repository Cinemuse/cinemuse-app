import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/profile/domain/profile_stats.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/stats_display.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/agenda_widget.dart';
import 'package:cinemuse_app/shared/widgets/carousels/poster_carousel_row.dart';
import 'package:cinemuse_app/shared/widgets/carousels/generic_carousel_row.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ProfileOverview extends ConsumerWidget {
  const ProfileOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(recentlyWatchedStreamProvider);
    final history = historyAsync.valueOrNull ?? [];
    
    final groupedMovies = history.where((h) => h.mediaType == MediaKind.movie).toList();
    final groupedSeries = history.where((h) => h.mediaType == MediaKind.tv).toList();
    final statsAsync = ref.watch(profileStatsProvider);
    final stats = statsAsync.valueOrNull ?? ProfileStats.empty();

    String formatDuration(int minutes) {
      final d = minutes ~/ 1440;
      final h = (minutes % 1440) ~/ 60;
      return '${d}d ${h}h';
    }

    final appLanguage = ref.watch(settingsProvider).appLanguage;

    Widget buildRecentRow(String title, IconData icon, List<MediaItem> items) {
      final cards = items.map((item) {
        return MediaCard(
          title: item.getLocalizedTitle(appLanguage) ?? 'Unknown',
          posterPath: item.posterPath,
          releaseDate: item.releaseDate?.year.toString(),
          rating: item.voteAverage,
          tmdbId: item.tmdbId,
          mediaType: item.mediaType,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => MediaDetailsScreen(
                mediaId: item.tmdbId.toString(),
                mediaType: item.mediaType.name,
              ),
            ));
          },
          onPlay: () {
            Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
              builder: (_) => VideoPlayerScreen(
                queryId: item.tmdbId.toString(),
                type: item.mediaType.name,
              ),
            ));
          },
        );
      }).toList();

      return PosterCarouselRow(
        title: title,
        icon: icon,
        theme: CarouselTheme.profileRow,
        items: cards,
        emptyBuilder: (context) => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0, horizontal: 24),
          child: Text('No recently watched items', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        final horizontalPadding = AppTheme.getResponsiveHorizontalPadding(context);

        return SingleChildScrollView(
          padding: EdgeInsets.only(
            top: 24,
            left: horizontalPadding,
            right: horizontalPadding,
            bottom: horizontalPadding,
          ),
          child: isDesktop
              ? Stack(
                  children: [
                    // Driver Row: Determines the height and layout widths based on the left column
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column (Driver)
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: TimeBreakdownCard(stats: stats, formatDuration: formatDuration)),
                                  const SizedBox(width: 24),
                                  Expanded(child: MoviesStatsCard(stats: stats)),
                                ],
                              ),
                              const SizedBox(height: 24),
                              buildRecentRow(
                                'RECENT MOVIES', 
                                LucideIcons.film, 
                                groupedMovies.take(10).map((h) => h.media).whereType<MediaItem>().toList()
                              ),
                              const SizedBox(height: 24),
                              buildRecentRow(
                                'RECENT SERIES', 
                                LucideIcons.tv, 
                                groupedSeries.take(10).map((h) => h.media).whereType<MediaItem>().toList()
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Right Column Width Placeholder (does not contribute to height)
                        const Expanded(
                          flex: 1,
                          child: SizedBox.shrink(),
                        ),
                      ],
                    ),
                    // Content Row: Forced to match the height of the driver row
                    Positioned.fill(
                      child: Row(
                        children: [
                          const Expanded(flex: 2, child: SizedBox.shrink()),
                          const SizedBox(width: 24),
                          // The actual right column content
                          Expanded(
                            flex: 1,
                            child: Column(
                              children: [
                                SeriesStatsCard(stats: stats),
                                const SizedBox(height: 24),
                                const Expanded(child: AgendaWidget(isExpanded: true)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats
                    const StatsDisplay(),
                    const SizedBox(height: 32),

                    // Recent Movies Container
                    buildRecentRow(
                      'RECENT MOVIES', 
                      LucideIcons.film, 
                      groupedMovies.take(10).map((h) => h.media).whereType<MediaItem>().toList()
                    ),

                    const SizedBox(height: 24),

                    // Recent Series Container
                    buildRecentRow(
                      'RECENT SERIES', 
                      LucideIcons.tv, 
                      groupedSeries.take(10).map((h) => h.media).whereType<MediaItem>().toList()
                    ),
                    
                    const SizedBox(height: 32),

                    // Agenda
                    const AgendaWidget(),
                    const SizedBox(height: 32),
                  ],
                ),
        );
      },
    );
  }
}


