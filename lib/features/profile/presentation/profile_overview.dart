import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/features/profile/application/title_marks_provider.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/stats_display.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/agenda_widget.dart';
import 'package:cinemuse_app/shared/widgets/carousels/poster_carousel_row.dart';
import 'package:cinemuse_app/shared/widgets/carousels/generic_carousel_row.dart';
import 'package:cinemuse_app/shared/widgets/error_card.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/title_list_actions.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/profile/presentation/watch_history_screen.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ProfileOverview extends ConsumerWidget {
  const ProfileOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(recentlyWatchedStreamProvider);
    final history = historyAsync.value ?? [];

    final groupedMovies = history
        .where((h) => h.mediaType == MediaKind.movie)
        .toList();
    final groupedSeries = history
        .where((h) => h.mediaType == MediaKind.tv)
        .toList();
    final statsAsync = ref.watch(profileStatsProvider);
    // null until the first stats arrive: the cards show "–". A failed refresh
    // keeps the last stats, so the error card is only for the first load
    // (REV-269).
    final stats = statsAsync.value;
    final statsError = statsAsync.hasError && stats == null
        ? ref.read(errorMapperProvider).map(statsAsync.error!)
        : null;
    final l10n = AppLocalizations.of(context)!;

    final appLanguage = ref.watch(settingsProvider).appLanguage;

    void openWatchHistory(MediaKind type) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WatchHistoryScreen(initialType: type),
        ),
      );
    }

    Widget buildRecentRow(
      String title,
      IconData icon,
      List<MediaItem> items, {
      VoidCallback? onHeaderTap,
    }) {
      final cards = items.map((item) {
        return MediaCard(
          title: item.getLocalizedTitle(appLanguage) ?? l10n.commonUnknown,
          posterPath: item.posterPath,
          releaseDate: item.releaseDate?.year.toString(),
          rating: item.voteAverage,
          listActions: TitleListActions(context, ref, item),
          marks: ref.watch(
            titleMarksProvider((
              tmdbId: item.tmdbId,
              mediaType: item.mediaType,
              place: MarksPlace.history,
            )),
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MediaDetailsScreen(
                  mediaId: item.tmdbId.toString(),
                  mediaType: item.mediaType.name,
                ),
              ),
            );
          },
          onPlay: () {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => VideoPlayerScreen(
                  queryId: item.tmdbId.toString(),
                  type: item.mediaType.name,
                ),
              ),
            );
          },
        );
      }).toList();

      return PosterCarouselRow(
        title: title,
        icon: icon,
        theme: CarouselTheme.profileRow,
        items: cards,
        onHeaderTap: onHeaderTap,
        emptyBuilder: (context) {
          final isMobile = Breakpoints.isCompact(context);
          return Padding(
            padding: EdgeInsets.symmetric(
              vertical: 24.0,
              horizontal: isMobile ? 16.0 : 24.0,
            ),
            child: Text(
              l10n.profileNoRecentItems,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          );
        },
      );
    }

    List<MediaItem> recentMedia(List<WatchHistory> list) =>
        list.take(10).map((h) => h.media).whereType<MediaItem>().toList();
    // Built once: the wide and narrow layouts show the same rows (REV-110).
    final recentMoviesRow = buildRecentRow(
      l10n.profileRecentMovies.toUpperCase(),
      LucideIcons.film,
      recentMedia(groupedMovies),
      onHeaderTap: () => openWatchHistory(MediaKind.movie),
    );
    final recentSeriesRow = buildRecentRow(
      l10n.profileRecentSeries.toUpperCase(),
      LucideIcons.tv,
      recentMedia(groupedSeries),
      onHeaderTap: () => openWatchHistory(MediaKind.tv),
    );

    Widget statsErrorCard(UserFriendlyError error) => ErrorCard(
      error: error,
      onRetry: () => ref.invalidate(profileStatsProvider),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= Breakpoints.medium;
        final horizontalPadding = AppTheme.getResponsiveHorizontalPadding(
          context,
        );

        // Plain content: the Profile page is the one scroll view (REV-239).
        return Padding(
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
                        // Left Column (Driver). Each column is its own Tab
                        // order group: Tab finishes one before the other.
                        Expanded(
                          flex: 2,
                          child: FocusTraversalGroup(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (statsError != null) ...[
                                  statsErrorCard(statsError),
                                  const SizedBox(height: 24),
                                ],
                                Row(
                                  children: [
                                    Expanded(
                                      child: TimeBreakdownCard(stats: stats),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      child: MoviesStatsCard(stats: stats),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                recentMoviesRow,
                                const SizedBox(height: 24),
                                recentSeriesRow,
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Right Column Width Placeholder (does not contribute to height)
                        const Expanded(flex: 1, child: SizedBox.shrink()),
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
                            child: FocusTraversalGroup(
                              child: Column(
                                children: [
                                  SeriesStatsCard(stats: stats),
                                  const SizedBox(height: 24),
                                  const Expanded(
                                    child: AgendaWidget(isExpanded: true),
                                  ),
                                ],
                              ),
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
                    if (statsError != null) ...[
                      statsErrorCard(statsError),
                      const SizedBox(height: 16),
                    ],
                    const StatsDisplay(),
                    const SizedBox(height: 16),

                    // Recent Movies Container
                    recentMoviesRow,

                    const SizedBox(height: 12),

                    // Recent Series Container
                    recentSeriesRow,

                    const SizedBox(height: 16),

                    // Agenda
                    const AgendaWidget(),
                    const SizedBox(height: 16),
                  ],
                ),
        );
      },
    );
  }
}
