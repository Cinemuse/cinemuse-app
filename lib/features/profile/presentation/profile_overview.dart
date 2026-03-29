import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/profile/domain/profile_stats.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/stats_display.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/agenda_widget.dart';
import 'package:cinemuse_app/shared/widgets/horizontal_media_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ProfileOverview extends ConsumerWidget {
  const ProfileOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(watchHistoryStreamProvider);
    final history = historyAsync.valueOrNull ?? [];
    
    // Group history items by tmdbId to show each title only once
    List<WatchHistory> groupHistory(List<WatchHistory> items) {
      final groups = <int, WatchHistory>{};
      for (final item in items) {
        if (!groups.containsKey(item.tmdbId)) {
          groups[item.tmdbId] = item;
        } else if (item.lastWatchedAt.isAfter(groups[item.tmdbId]!.lastWatchedAt)) {
          groups[item.tmdbId] = item;
        }
      }
      return groups.values.toList()
        ..sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));
    }

    final groupedMovies = groupHistory(history.where((h) => h.mediaType == MediaKind.movie).toList());
    final groupedSeries = groupHistory(history.where((h) => h.mediaType == MediaKind.tv).toList());
    final statsAsync = ref.watch(profileStatsProvider);
    final stats = statsAsync.valueOrNull ?? ProfileStats.empty();

    String formatDuration(int minutes) {
      final d = minutes ~/ 1440;
      final h = (minutes % 1440) ~/ 60;
      return '${d}d ${h}h';
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
                              _RecentMediaContainer(
                                title: 'RECENT MOVIES',
                                icon: LucideIcons.film,
                                items: groupedMovies.take(10).toList(),
                              ),
                              const SizedBox(height: 24),
                              _RecentMediaContainer(
                                title: 'RECENT SERIES',
                                icon: LucideIcons.tv,
                                items: groupedSeries.take(10).toList(),
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
                    _RecentMediaContainer(
                      title: 'RECENT MOVIES',
                      icon: LucideIcons.film,
                      items: groupedMovies.take(10).toList(),
                    ),

                    const SizedBox(height: 24),

                    // Recent Series Container
                    _RecentMediaContainer(
                      title: 'RECENT SERIES',
                      icon: LucideIcons.tv,
                      items: groupedSeries.take(10).toList(),
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

class _RecentMediaContainer extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<WatchHistory> items;

  const _RecentMediaContainer({
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(LucideIcons.chevronRight, size: 16, color: Colors.grey),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Content
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0, horizontal: 24),
                child: Text(
                  'No recently watched items',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              // We use HorizontalMediaList with balanced dimensions (Height 360, Width 160)
              // We move padding to the list itself to allow items to scroll to the edge
              HorizontalMediaList(
                items: items.map((h) => h.media).whereType<MediaItem>().toList(),
                height: 340,
                itemWidth: 200,
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
          ],
        ),
      ),
    );
  }
}

