import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/shared/widgets/hover_scale.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/presentation/details/widgets/details_hero.dart';
import 'package:cinemuse_app/features/media/presentation/details/widgets/episode_list.dart';
import 'package:cinemuse_app/features/media/presentation/details/widgets/cast_carousel.dart';
import 'package:cinemuse_app/features/media/presentation/details/widgets/videos_carousel.dart';
import 'package:cinemuse_app/features/media/presentation/details/widgets/info_boxes.dart';
import 'package:cinemuse_app/features/media/presentation/details/widgets/external_links.dart';
import 'package:cinemuse_app/features/navigation/navbar.dart';
import 'package:cinemuse_app/features/navigation/nav_providers.dart';
import 'package:cinemuse_app/features/settings/presentation/settings_screen.dart';
import 'package:cinemuse_app/features/search/presentation/search_overlay.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/shared/widgets/bento_box.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cinemuse_app/features/home/application/home_providers.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/add_to_list_modal.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';

class MediaDetailsScreen extends ConsumerStatefulWidget {
  final String mediaId;
  final String mediaType;

  const MediaDetailsScreen({
    super.key,
    required this.mediaId,
    required this.mediaType,
  });

  @override
  ConsumerState<MediaDetailsScreen> createState() => _MediaDetailsScreenState();
}

class _MediaDetailsScreenState extends ConsumerState<MediaDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final detailsAsync = ref.watch(mediaDetailsProvider((id: widget.mediaId, type: widget.mediaType)));
    final watchHistoryAsync = ref.watch(mediaWatchHistoryProvider(widget.mediaId));
    final watchHistory = watchHistoryAsync.value;

    final responsivePadding = AppTheme.getResponsiveHorizontalPadding(context);

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: detailsAsync.when(
        data: (details) {
          if (details == null) return const Center(child: Text('Not found'));
          final l10n = AppLocalizations.of(context)!;
          final isSeries = widget.mediaType == 'tv' || widget.mediaType == 'series';

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // Hero
                  SliverToBoxAdapter(
                    child: DetailsHero(
                      media: {'id': widget.mediaId, 'type': widget.mediaType},
                      details: details,
                      resumeData: watchHistory != null ? {
                        'type': watchHistory.mediaType.name == 'episode' ? 'tv' : 'movie',
                        'season': watchHistory.season,
                        'episode': watchHistory.episode,
                        'progress': watchHistory.progressSeconds,
                      } : null,
                      isInWatchlist: ref.watch(userListsProvider).when(
                        data: (lists) => ref.read(userListsProvider.notifier).isInWatchlist(
                          int.parse(widget.mediaId), 
                          MediaItem.fromString(widget.mediaType),
                        ),
                        loading: () => false,
                        error: (_, __) => false,
                      ),
                      isFavorite: ref.watch(userListsProvider).when(
                        data: (lists) => ref.read(userListsProvider.notifier).isFavorite(
                          int.parse(widget.mediaId), 
                          MediaItem.fromString(widget.mediaType),
                        ),
                        loading: () => false,
                        error: (_, __) => false,
                      ),
                      onHeartTap: () async {
                        final mediaItem = MediaItem(
                          tmdbId: int.parse(widget.mediaId),
                          mediaType: MediaItem.fromString(widget.mediaType),
                          title: details['title'] ?? details['name'] ?? '',
                          posterPath: details['poster_path'],
                          backdropPath: details['backdrop_path'],
                          voteAverage: (details['vote_average'] as num?)?.toDouble(),
                          releaseDate: details['release_date'] != null || details['first_air_date'] != null
                              ? DateTime.tryParse(details['release_date'] ?? details['first_air_date'])
                              : null,
                          updatedAt: DateTime.now(),
                        );
                        final notifier = ref.read(userListsProvider.notifier);
                        await notifier.toggleFavorite(mediaItem);
                      },
                      onBookmarkTap: () async {
                        final mediaItem = MediaItem(
                          tmdbId: int.parse(widget.mediaId),
                          mediaType: MediaItem.fromString(widget.mediaType),
                          title: details['title'] ?? details['name'] ?? '',
                          posterPath: details['poster_path'],
                          backdropPath: details['backdrop_path'],
                          voteAverage: (details['vote_average'] as num?)?.toDouble(),
                          releaseDate: details['release_date'] != null || details['first_air_date'] != null
                              ? DateTime.tryParse(details['release_date'] ?? details['first_air_date'])
                              : null,
                          updatedAt: DateTime.now(),
                        );
                        final notifier = ref.read(userListsProvider.notifier);
                        await notifier.toggleWatchlist(mediaItem);
                      },
                      onListTap: () {
                        final mediaItem = MediaItem(
                          tmdbId: int.parse(widget.mediaId),
                          mediaType: MediaItem.fromString(widget.mediaType),
                          title: details['title'] ?? details['name'] ?? '',
                          posterPath: details['poster_path'],
                          backdropPath: details['backdrop_path'],
                          voteAverage: (details['vote_average'] as num?)?.toDouble(),
                          releaseDate: details['release_date'] != null || details['first_air_date'] != null
                              ? DateTime.tryParse(details['release_date'] ?? details['first_air_date'])
                              : null,
                          updatedAt: DateTime.now(),
                        );
                        showDialog(
                          context: context,
                          builder: (context) => AddToListModal(media: mediaItem),
                        );
                      },
                      onPlayClick: () {
                        // Determine start parameters
                        int? season;
                        int? episode;
                        
                        if (isSeries) {
                          // For series, resume last watched or start at S1E1
                          season = watchHistory?.season ?? 1;
                          episode = watchHistory?.episode ?? 1;
                        }

                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => VideoPlayerScreen(
                            queryId: widget.mediaId,
                            type: widget.mediaType,
                            season: season,
                            episode: episode,
                            startPosition: watchHistory?.progressSeconds ?? 0,
                          ),
                        ));
                      },
                      onDeepSearch: (_) {},
                      contentPadding: responsivePadding,
                    ),
                  ),

                  // Main Content Area
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: responsivePadding, vertical: 48),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column (2/3)
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Seasons (Series only)
                                if (isSeries && (details['number_of_seasons'] ?? 0) > 0) ...[
                                  _buildStableSeasonHeader(context, details),
                                  const SizedBox(height: 16),
                                  _buildStableEpisodeList(context, details),
                                  const SizedBox(height: 32),
                                ],

                                // Synopsis in BentoBox
                                BentoBox(
                                  title: l10n.detailsSynopsis,
                                  icon: LucideIcons.terminal,
                                  child: Text(
                                    details['overview'] ?? '',
                                    style: DesktopTypography.bodyPrimary,
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Cast
                                CastCarousel(credits: details['credits']),
                                const SizedBox(height: 24),

                                // Trailers
                                VideosCarousel(videos: details['videos']),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Right Column (Sidebar)
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: 320,
                              maxWidth: 420,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CreativeVisionBox(details: details, isSeries: widget.mediaType == 'tv'),
                                const SizedBox(height: 24),
                                VerdictBox(
                                  reviews: details['reviews']?['results'] ?? [],
                                  onShowUserReviewModal: () {},
                                  onShowReviewsModal: () {},
                                ),
                                const SizedBox(height: 24),
                                ExternalLinks(
                                  externalIds: details['external_ids'],
                                  title: details['title'] ?? details['name'] ?? '',
                                  homepage: details['homepage'],
                                  type: widget.mediaType,
                                  tmdbId: details['id'],
                                ),
                                if (details['budget'] != null && details['budget'] > 0) ...[
                                  const SizedBox(height: 24),
                                  FinancesBox(budget: details['budget'] ?? 0, revenue: details['revenue'] ?? 0),
                                ],
                                const SizedBox(height: 24),
                                ProductionDNA(
                                  productionCompanies: details['production_companies'] ?? [],
                                  onCompanyClick: (_) {},
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),

              // Top Navbar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AppNavbar(
                  currentIndex: ref.watch(navIndexProvider),
                  onTap: (index) {
                    ref.read(navIndexProvider.notifier).state = index;
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  onSettingsTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                  onLogoutTap: () {
                    ref.read(authProvider.notifier).signOut();
                  },
                  onSearchTap: () => SearchOverlay.show(context),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildStableSeasonHeader(BuildContext context, Map<String, dynamic> details) {
    final l10n = AppLocalizations.of(context)!;
    final selectedSeason = ref.watch(selectedSeasonProvider);
    final numberOfSeasons = details['number_of_seasons'] as int? ?? 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l10n.detailsEpisodesRegistry.toUpperCase(), style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
        PopupMenuButton<int>(
          initialValue: selectedSeason,
          onSelected: (val) => ref.read(selectedSeasonProvider.notifier).state = val,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Text(l10n.detailsSeasonNumber(selectedSeason), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  const Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.white54),
                ],
              ),
            ),
          ),
          itemBuilder: (context) => List.generate(numberOfSeasons, (i) => i + 1).map((n) => PopupMenuItem(value: n, child: Text('Season $n'))).toList(),
        ),
      ],
    );
  }

  Widget _buildStableEpisodeList(BuildContext context, Map<String, dynamic> details) {
    final selectedSeason = ref.watch(selectedSeasonProvider);
    final seasonDataAsync = ref.watch(seasonDetailsProvider((tmdbId: int.parse(widget.mediaId), seasonNumber: selectedSeason)));

    return seasonDataAsync.when(
      data: (data) => SizedBox(
        height: 280,
        child: EpisodeList(episodes: data?['episodes'], seasonNumber: selectedSeason, media: details),
      ),
      loading: () => const SizedBox(height: 280, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (e, _) => Text('Error loading episodes: $e'),
    );
  }
}
