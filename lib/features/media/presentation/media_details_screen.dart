import 'package:cinemuse_app/features/media/application/media_details_controller.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/tracking_modals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/details_hero.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episode_list.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/cast_carousel.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/videos_carousel.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/info_boxes.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/external_links.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/add_to_list_modal.dart';
import 'package:cinemuse_app/shared/widgets/bento_box.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:lucide_icons/lucide_icons.dart';

class MediaDetailsScreen extends ConsumerStatefulWidget {
  final String mediaId;
  final String mediaType; // 'movie' or 'tv'/'series'

  const MediaDetailsScreen({
    super.key,
    required this.mediaId,
    required this.mediaType,
  });

  @override
  ConsumerState<MediaDetailsScreen> createState() => _MediaDetailsScreenState();
}

class _MediaDetailsScreenState extends ConsumerState<MediaDetailsScreen> {
  bool _hasInitializedSeason = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final typeForTmdb = widget.mediaType == 'series' ? 'tv' : widget.mediaType;
    final detailsAsync = ref.watch(mediaDetailsProvider((id: widget.mediaId, type: typeForTmdb)));
    final controller = ref.read(mediaDetailsControllerProvider.notifier);
    final responsivePadding = AppTheme.getResponsiveHorizontalPadding(context);

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: detailsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white))),
        data: (details) {
          if (details == null) return const Center(child: Text('Not found', style: TextStyle(color: Colors.white)));

          final tmdbId = int.parse(widget.mediaId);
          final isTV = typeForTmdb == 'tv';

          // Track list status
          final mediaKind = isTV ? MediaKind.tv : MediaKind.movie;
          final isFavorite = ref.watch(userListsProvider.notifier).isFavorite(tmdbId, mediaKind);
          final isInWatchlist = ref.watch(userListsProvider.notifier).isInWatchlist(tmdbId, mediaKind);

          // Watch history data
          final watchHistory = ref.watch(mediaWatchHistoryProvider(widget.mediaId)).value;
          
          // Auto-select season based on history
          ref.listen(mediaWatchHistoryProvider(widget.mediaId), (previous, next) {
             final nextHistory = next.value;
             // Only auto-switch if we haven't manually interacted yet?
             // Actually, this hook runs on init too if we use FireImmediately? No, just listen.
             // But we are inside build.
             if (nextHistory != null && nextHistory.season != null && nextHistory.season! > 0) {
               // We only want to set this ONCE when opening the page, not every time history updates 
               // (e.g. while watching an episode and marking it).
               // But managing a "once" flag inside build with listen is tricky.
             }
          });

          // Better approach: Use a flag in State and check in build
          if (!_hasInitializedSeason && watchHistory != null && watchHistory.season != null && watchHistory.season! > 0) {
             _hasInitializedSeason = true;
             
             int targetSeason = watchHistory.season!;
             
             // Check if this season is fully watched
             final seasonData = (details['seasons'] as List?)?.firstWhere(
               (s) => s['season_number'] == targetSeason, 
               orElse: () => null
             );
             
             if (seasonData != null) {
               final episodeCount = seasonData['episode_count'] as int? ?? 0;
               final watchedEpisodesMap = ref.read(watchedEpisodesMapProvider(tmdbId));
               
               bool isSeasonCompleted = true;
               if (episodeCount > 0) {
                 for (int i = 1; i <= episodeCount; i++) {
                   if ((watchedEpisodesMap['$targetSeason-$i'] ?? 0) == 0) {
                     isSeasonCompleted = false;
                     break;
                   }
                 }
               } else {
                 isSeasonCompleted = false;
               }
               
               if (isSeasonCompleted) {
                 // Check if next season exists
                 final nextSeasonData = (details['seasons'] as List?)?.firstWhere(
                   (s) => s['season_number'] == targetSeason + 1, 
                   orElse: () => null
                 );
                 
                 if (nextSeasonData != null) {
                   targetSeason++;
                   // Also ensure this new start episode is in "Continue Watching"
                   // We don't await this to keep UI fast, but we fire it.
                   // We need to know if we should do this? Yes, user requested it.
                   // Check if we are "watching" the first episode of next season?
                   // The repository logic handles the "if not exists" check.
                   ref.read(mediaDetailsControllerProvider.notifier).ensureEpisodeWatching(
                     tmdbId: tmdbId,
                     season: targetSeason,
                     episode: 1, 
                   );
                 }
               }
             }

             // Schedule update
             WidgetsBinding.instance.addPostFrameCallback((_) {
               ref.read(selectedSeasonProvider(widget.mediaId).notifier).state = targetSeason;
             });
          }

          final seriesWatchStatus = isTV
              ? ref.watch(seriesWatchStatusProvider((
                  tmdbId: tmdbId,
                  totalEpisodes: details['number_of_episodes'] as int? ?? 0,
                )))
              : null;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: DetailsHero(
                  media: {'id': widget.mediaId, 'type': typeForTmdb},
                  details: details,
                  isFavorite: isFavorite,
                  isInWatchlist: isInWatchlist,
                  resumeData: watchHistory != null ? {
                    // map 'tv' mediaType to 'tv' string to ensure DetailsHero picks it up
                    'type': (watchHistory.mediaType == MediaKind.episode || watchHistory.mediaType == MediaKind.tv) ? 'tv' : 'movie',
                    'season': watchHistory.season,
                    'episode': watchHistory.episode,
                    'progress': watchHistory.progressSeconds,
                  } : null,
                  seriesWatchStatus: seriesWatchStatus,
                  onPlayClick: () => _handlePlay(context, watchHistory, typeForTmdb),
                  onDeepSearch: (params) => {},
                  onListTap: () => _showAddToList(context, tmdbId, typeForTmdb, details),
                  onTrackTap: isTV ? () => _showSeriesTrackModal(context, controller, tmdbId, details, seriesWatchStatus) : null,
                  contentPadding: responsivePadding,
                ),
              ),
              
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
                            if (isTV && (details['number_of_seasons'] ?? 0) > 0) ...[
                              _SeriesEpisodesSection(mediaId: widget.mediaId, details: details),
                              const SizedBox(height: 32),
                            ],

                            BentoBox(
                              title: l10n.detailsSynopsis,
                              icon: LucideIcons.terminal,
                              child: Text(
                                details['overview'] ?? '',
                                style: DesktopTypography.bodyPrimary,
                              ),
                            ),
                            const SizedBox(height: 24),

                            CastCarousel(credits: details['credits']),
                            const SizedBox(height: 24),

                            VideosCarousel(videos: details['videos']),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      
                      // Right Column (Sidebar)
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 320, maxWidth: 420),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CreativeVisionBox(details: details, isSeries: isTV),
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
                              type: typeForTmdb,
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
          );
        },
      ),
    );
  }

  void _handlePlay(BuildContext context, WatchHistory? watchHistory, String type) {
    int? season;
    int? episode;
    
    if (type == 'tv') {
      season = watchHistory?.season ?? 1;
      episode = watchHistory?.episode ?? 1;
    }

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VideoPlayerScreen(
        queryId: widget.mediaId,
        type: type,
        season: season,
        episode: episode,
        startPosition: watchHistory?.progressSeconds ?? 0,
      ),
    ));
  }

  void _handleDeepSearch(Map<String, dynamic> params) {
    // Implement search navigation or filtering
  }

  void _showAddToList(BuildContext context, int tmdbId, String type, Map<String, dynamic> details) {
    final mediaItem = MediaItem(
      tmdbId: tmdbId,
      mediaType: MediaItem.fromString(type),
      title: details['title'] ?? details['name'] ?? '',
      posterPath: details['poster_path'],
      backdropPath: details['backdrop_path'],
      voteAverage: (details['vote_average'] as num?)?.toDouble(),
      releaseDate: DateTime.tryParse(details['release_date'] ?? details['first_air_date'] ?? ''),
      updatedAt: DateTime.now(),
    );
    showDialog(
      context: context,
      builder: (context) => AddToListModal(media: mediaItem),
    );
  }

  void _showSeriesTrackModal(
    BuildContext context, 
    MediaDetailsController controller, 
    int tmdbId, 
    Map<String, dynamic> details,
    ({bool isFullyWatched, bool isPartiallyWatched, int minWatchCount})? status,
  ) {
    if (status == null) return;

    showDialog(
      context: context,
      builder: (context) => SeriesTrackModal(
        title: details['name'] ?? 'Series',
        status: status,
        onMarkRemaining: (date) => _markAllEpisodes(controller, tmdbId, details, date, onlyRemaining: true),
        onMarkAll: (date) => _markAllEpisodes(controller, tmdbId, details, date, onlyRemaining: false),
        onRemoveAll: () => controller.deleteAllSeriesLogs(tmdbId: tmdbId),
      ),
    );
  }

  void _markAllEpisodes(MediaDetailsController controller, int tmdbId, Map<String, dynamic> details, DateTime? date, {required bool onlyRemaining}) {
    final List<({int season, int episode})> episodesToMark = [];
    final seasons = details['seasons'] as List? ?? [];
    
    final watchedMap = ref.read(watchedEpisodesMapProvider(tmdbId));

    for (var season in seasons) {
      final sNum = season['season_number'] as int? ?? 0;
      if (sNum == 0) continue;
      final epCount = season['episode_count'] as int? ?? 0;
      for (int e = 1; e <= epCount; e++) {
        if (onlyRemaining && (watchedMap['$sNum-$e'] ?? 0) > 0) continue;
        episodesToMark.add((season: sNum, episode: e));
      }
    }

    if (episodesToMark.isEmpty) return;
    controller.logMultipleEpisodes(tmdbId: tmdbId, episodes: episodesToMark, loggedAt: date);
  }
}

class _SeriesEpisodesSection extends ConsumerWidget {
  final String mediaId;
  final Map<String, dynamic> details;

  const _SeriesEpisodesSection({required this.mediaId, required this.details});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tmdbId = int.parse(mediaId);
    final selectedSeason = ref.watch(selectedSeasonProvider(mediaId));
    final seasonDetailsAsync = ref.watch(seasonDetailsProvider((tmdbId: tmdbId, seasonNumber: selectedSeason)));
    
    final watchedEpisodesMap = ref.watch(watchedEpisodesMapProvider(tmdbId));
    final episodeProgressMap = ref.watch(episodeProgressMapProvider(tmdbId)).value;
    
    return BentoBox(
      title: l10n.detailsEpisodesRegistry,
      icon: LucideIcons.tv,
      action: _SeasonSelector(media: details, selectedSeason: selectedSeason, mediaId: mediaId),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 500, maxHeight: 500),
        child: seasonDetailsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)),
          error: (err, _) => Center(child: Text('Error loading season: $err')),
          data: (season) {
            if (season == null) return const Center(child: Text('Season details not found'));
            final episodes = season['episodes'] as List? ?? [];
            
            // Calculate initial scroll index (first unwatched episode)
            int initialIndex = 0;
            // Only auto-scroll if we have watch history for this season to avoid jumping on fresh seasons
            // actually we want to jump to next episode even if it's the first one? 
            // The user said "load on the next unwatched episode".
            // If the season is fully unwatched, index 0 is correct.
            // If season is partially watched, find the first one that is NOT watched.
            
            if (watchedEpisodesMap.isNotEmpty) {
               for (int i = 0; i < episodes.length; i++) {
                 final ep = episodes[i];
                 final epNum = ep['episode_number'] as int;
                 final key = '$selectedSeason-$epNum';
                 if ((watchedEpisodesMap[key] ?? 0) == 0) {
                   initialIndex = i;
                   break;
                 }
               }
               // If all are watched? Then maybe scroll to end? Or keep 0.
               // If last episode is watched, maybe we shouldn't scroll? 
               // Let's stick to "next unwatched". If all watched, it will be 0 (re-watch from start) or we can check.
               // If all scanned and all watched, `initialIndex` remains 0 (first ep) or should remain last?
               // Let's refine:
               bool foundUnwatched = false;
               for (int i = 0; i < episodes.length; i++) {
                 final ep = episodes[i];
                 final epNum = ep['episode_number'] as int;
                 final key = '$selectedSeason-$epNum';
                 if ((watchedEpisodesMap[key] ?? 0) == 0) {
                   initialIndex = i;
                   foundUnwatched = true;
                   break;
                 }
               }
               if (!foundUnwatched) {
                 // All watched, maybe scroll to end?
                 // or just 0. Let's keep 0 for now.
               }
            }

            return EpisodeList(
              episodes: episodes,
              seasonNumber: selectedSeason,
              media: details,
              watchedEpisodesCount: watchedEpisodesMap,
              episodeProgress: episodeProgressMap,
              initialScrollIndex: initialIndex,
              onEpisodeTap: (s, e, name) {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => VideoPlayerScreen(
                    queryId: mediaId,
                    type: 'tv',
                    season: s,
                    episode: e,
                    episodeTitle: name,
                  ),
                ));
              },
            );
          },
        ),
      ),
    );
  }
}

class _SeasonSelector extends ConsumerWidget {
  final Map<String, dynamic> media;
  final int selectedSeason;
  final String mediaId;

  const _SeasonSelector({required this.media, required this.selectedSeason, required this.mediaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasons = (media['seasons'] as List? ?? [])
        .where((s) => (s['season_number'] as int? ?? 0) > 0)
        .toList();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: PopupMenuButton<int>(
        initialValue: selectedSeason,
        onSelected: (val) => ref.read(selectedSeasonProvider(mediaId).notifier).state = val,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white10, 
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'Season $selectedSeason',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.white54),
              ],
            ),
          ),
        ),
        itemBuilder: (context) => seasons.map((s) => PopupMenuItem<int>(
          value: s['season_number'] as int, 
          child: Text('Season ${s['season_number']}', style: const TextStyle(fontSize: 13))
        )).toList(),
      ),
    );
  }
}

class ShimmerDetailsLoading extends StatelessWidget {
  const ShimmerDetailsLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(height: 400, color: Colors.white10),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 30, width: 200, color: Colors.white10),
              const SizedBox(height: 16),
              Container(height: 100, color: Colors.white10),
            ],
          ),
        ),
      ],
    );
  }
}
