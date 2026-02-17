import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/core/services/supabase_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/application/store/watch_history_store.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
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
          
          // Global series watch status
          final seriesWatchStatus = widget.mediaType == 'series' || widget.mediaType == 'tv'
            ? ref.watch(seriesWatchStatusProvider((
                tmdbId: int.parse(widget.mediaId),
                totalEpisodes: details['number_of_episodes'] as int? ?? 0,
              )))
            : null;
          if (details == null) return const Center(child: Text('Not found'));
          final l10n = AppLocalizations.of(context)!;
          final isSeries = widget.mediaType == 'tv' || widget.mediaType == 'series';
          
          // Transform episodic logs into the nested structure DetailsHero expects:
          // {'s': {'1': {'1': {}, '2': {}}, '2': {...}}}
          Map<String, dynamic>? episodicProgress;
          if (isSeries) {
            final logsAsync = ref.watch(seriesWatchLogsProvider(int.parse(widget.mediaId)));
            final logs = logsAsync.value ?? [];
            if (logs.isNotEmpty) {
              final seasonsMap = <String, Map<String, dynamic>>{};
              for (final log in logs) {
                final s = log['season']?.toString();
                final e = log['episode']?.toString();
                if (s != null && e != null) {
                  seasonsMap.putIfAbsent(s, () => <String, dynamic>{})[e] = {};
                }
              }
              episodicProgress = {'s': seasonsMap};
            }
          }

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
                      watchedData: episodicProgress,
                      seriesWatchStatus: seriesWatchStatus,
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
                      onDeepSearch: (args) => SearchOverlay.show(context),
                      onTrackTap: isSeries ? () => _showSeriesTrackOptions(
                        context, 
                        ref, 
                        details, 
                        seriesWatchStatus!
                      ) : null,
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
                                // Seasons & Episodes (Series only)
                                if (isSeries && (details['number_of_seasons'] ?? 0) > 0) ...[
                                  SeriesEpisodesSection(
                                    mediaId: widget.mediaId,
                                    details: details,
                                  ),
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

  void _showSeriesTrackOptions(
    BuildContext context, 
    WidgetRef ref, 
    Map<String, dynamic> details,
    ({bool isFullyWatched, bool isPartiallyWatched, int minWatchCount}) status,
  ) {
    final List<({int season, int episode})> allEpisodes = [];
    final seasons = details['seasons'] as List? ?? [];
    for (final s in seasons) {
      final sNum = s['season_number'] as int? ?? 0;
      if (sNum == 0) continue; // Skip specials
      final epCount = s['episode_count'] as int? ?? 0;
      for (int e = 1; e <= epCount; e++) {
        allEpisodes.add((season: sNum, episode: e));
      }
    }

    final watchedMap = ref.read(watchedEpisodesMapProvider(int.parse(widget.mediaId)));
    final List<({int season, int episode})> remainingEpisodes = allEpisodes.where((ep) {
      final key = '${ep.season}-${ep.episode}';
      return (watchedMap[key] ?? 0) == 0;
    }).toList();

    showDialog(
      context: context,
      builder: (context) => _SeriesTrackModal(
        title: details['name'] ?? 'Series',
        status: status,
        onMarkRemaining: (date) async {
          final userId = supabase.auth.currentUser?.id;
          if (userId == null) return;
          
          await ref.read(watchHistoryRepositoryProvider).logMultipleEpisodes(
            userId: userId,
            tmdbId: int.parse(widget.mediaId),
            episodes: remainingEpisodes,
            loggedAt: date,
          );
          ref.invalidate(seriesWatchLogsProvider(int.parse(widget.mediaId)));
        },
        onMarkAll: (date) async {
          final userId = supabase.auth.currentUser?.id;
          if (userId == null) return;
          
          await ref.read(watchHistoryRepositoryProvider).logMultipleEpisodes(
            userId: userId,
            tmdbId: int.parse(widget.mediaId),
            episodes: allEpisodes,
            loggedAt: date,
          );
          ref.invalidate(seriesWatchLogsProvider(int.parse(widget.mediaId)));
        },
        onRemoveAll: () async {
          final userId = supabase.auth.currentUser?.id;
          if (userId == null) return;
          
          await ref.read(watchHistoryRepositoryProvider).deleteAllSeriesLogs(
            userId: userId,
            tmdbId: int.parse(widget.mediaId),
          );
          ref.invalidate(seriesWatchLogsProvider(int.parse(widget.mediaId)));
        },
      ),
    );
  }
}

class SeriesEpisodesSection extends ConsumerWidget {
  final String mediaId;
  final Map<String, dynamic> details;

  const SeriesEpisodesSection({
    super.key,
    required this.mediaId,
    required this.details,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selectedSeason = ref.watch(selectedSeasonProvider(mediaId));
    final numberOfSeasons = details['number_of_seasons'] as int? ?? 0;
    
    // Watch history for this media (last watched)
    final watchHistoryAsync = ref.watch(mediaWatchHistoryProvider(mediaId));
    final watchHistory = watchHistoryAsync.value;
    
    // Map of "season-episode" -> watch_count for this series
    final watchedEpisodes = ref.watch(watchedEpisodesMapProvider(int.parse(mediaId)));
    
    // Fetch season data
    final seasonDataAsync = ref.watch(seasonDetailsProvider((
      tmdbId: int.parse(mediaId), 
      seasonNumber: selectedSeason
    )));

    return BentoBox(
      title: l10n.detailsEpisodesRegistry,
      icon: LucideIcons.tv,
      // Removed padding: EdgeInsets.zero to use default BentoBox padding (24, 0, 24, 24)
      action: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: PopupMenuButton<int>(
          constraints: const BoxConstraints(maxHeight: 300),
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
                      l10n.detailsSeasonNumber(selectedSeason), 
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 13, 
                        fontWeight: FontWeight.bold
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.white54),
                ],
              ),
            ),
          ),
          itemBuilder: (context) => List.generate(numberOfSeasons, (i) => i + 1)
              .map((n) => PopupMenuItem(
                    value: n, 
                    child: Text('Season $n', style: const TextStyle(fontSize: 13))
                  ))
              .toList(),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Episode List with Fixed Height Loading/Error states to prevent jitter
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 500, maxHeight: 500),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: seasonDataAsync.when(
                data: (data) {
                  if (data == null || data['episodes'] == null || (data['episodes'] as List).isEmpty) {
                    return Center(
                      key: ValueKey('empty_$selectedSeason'),
                      child: const Text('No episodes found'),
                    );
                  }
                  // All watch history for per-episode progress bars
                  final allHistoryAsync = ref.watch(watchHistoryStoreProvider);
                  final allHistory = allHistoryAsync.value ?? <String, WatchHistory>{};

                  return EpisodeList(
                    key: ValueKey('episodes_$selectedSeason'),
                    episodes: data['episodes'], 
                    seasonNumber: selectedSeason, 
                    media: details,
                    watchedData: watchHistory?.toJson(),
                    watchedEpisodesCount: watchedEpisodes,
                    episodeProgress: <String, WatchHistory>{
                      for (final item in allHistory.values)
                        if (item.tmdbId.toString() == mediaId && item.mediaType == MediaKind.tv && item.season != null && item.episode != null)
                          '${item.season}-${item.episode}': item
                    },
                    onEpisodeTap: (s, e) {
                      int startPos = 0;
                      if (watchHistory != null && watchHistory.season == s && watchHistory.episode == e) {
                        startPos = watchHistory.progressSeconds;
                      }

                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => VideoPlayerScreen(
                          queryId: mediaId,
                          type: 'tv',
                          season: s,
                          episode: e,
                          startPosition: startPos,
                        ),
                      ));
                    },
                    onMarkWatched: (season, episode, date) async {
                      final userId = supabase.auth.currentUser?.id;
                      if (userId == null) return;
                      
                      await ref.read(watchHistoryRepositoryProvider).logEpisodeWatch(
                        userId: userId,
                        tmdbId: int.parse(mediaId),
                        mediaType: 'tv',
                        season: season,
                        episode: episode,
                        loggedAt: date,
                      );
                      
                      // Explicitly refresh the logs
                      ref.invalidate(seriesWatchLogsProvider(int.parse(mediaId)));
                    },
                    onRemoveWatch: (season, episode) async {
                      final userId = supabase.auth.currentUser?.id;
                      if (userId == null) return;
                      
                      await ref.read(watchHistoryRepositoryProvider).deleteLatestEpisodeLog(
                        userId: userId,
                        tmdbId: int.parse(mediaId),
                        season: season,
                        episode: episode,
                      );

                      // Explicitly refresh the logs
                      ref.invalidate(seriesWatchLogsProvider(int.parse(mediaId)));
                    },
                    onRemoveAllWatch: (season, episode) async {
                      final userId = supabase.auth.currentUser?.id;
                      if (userId == null) return;
                      
                      await ref.read(watchHistoryRepositoryProvider).deleteAllEpisodeLogs(
                        userId: userId,
                        tmdbId: int.parse(mediaId),
                        season: season,
                        episode: episode,
                      );

                      // Explicitly refresh the logs
                      ref.invalidate(seriesWatchLogsProvider(int.parse(mediaId)));
                    },
                    onMarkMultipleWatched: (episodes) async {
                      final userId = supabase.auth.currentUser?.id;
                      if (userId == null) return;
                      
                      await ref.read(watchHistoryRepositoryProvider).logMultipleEpisodes(
                        userId: userId,
                        tmdbId: int.parse(mediaId),
                        episodes: episodes,
                      );
                      
                      // Explicitly refresh the logs
                      ref.invalidate(seriesWatchLogsProvider(int.parse(mediaId)));
                    },
                  );
                },
                loading: () => Center(
                  key: ValueKey('loading_$selectedSeason'),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                      SizedBox(height: 16),
                      Text('Loading episodes...', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                    ],
                  ),
                ),
                error: (e, _) => Center(
                  key: ValueKey('error_$selectedSeason'),
                  child: Text(
                    'Error loading episodes: $e',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeriesTrackModal extends StatefulWidget {
  final String title;
  final ({bool isFullyWatched, bool isPartiallyWatched, int minWatchCount}) status;
  final Function(DateTime? date) onMarkRemaining;
  final Function(DateTime? date) onMarkAll;
  final VoidCallback onRemoveAll;

  const _SeriesTrackModal({
    required this.title,
    required this.status,
    required this.onMarkRemaining,
    required this.onMarkAll,
    required this.onRemoveAll,
  });

  @override
  State<_SeriesTrackModal> createState() => _SeriesTrackModalState();
}

class _SeriesTrackModalState extends State<_SeriesTrackModal> {
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final isNew = !widget.status.isFullyWatched && !widget.status.isPartiallyWatched;
    
    return AlertDialog(
      backgroundColor: AppTheme.secondary,
      surfaceTintColor: Colors.transparent,
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.playlist_add_check, color: AppTheme.accent, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 18), overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isNew 
                ? 'Mark the entire series as watched?' 
                : 'Manage your history for this series.',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 24),
          
          // Mark Remaining / Mark All / Rewatch All
          InkWell(
            onTap: () {
              Navigator.pop(context);
              if (widget.status.isPartiallyWatched && !widget.status.isFullyWatched) {
                widget.onMarkRemaining(_selectedDate);
              } else {
                widget.onMarkAll(_selectedDate);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      !widget.status.isFullyWatched ? Icons.done_all : Icons.replay_circle_filled, 
                      color: AppTheme.accent, 
                      size: 20
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.status.isPartiallyWatched && !widget.status.isFullyWatched
                              ? 'Mark Remaining as Watched'
                              : (!widget.status.isFullyWatched ? 'Mark all as Watched' : 'Rewatch Whole Series'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          _selectedDate == null ? 'Today' : 'Watched on ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                          style: TextStyle(color: AppTheme.accent.withOpacity(0.7), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today, size: 18, color: AppTheme.accent),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(primary: AppTheme.accent, onPrimary: Colors.white, surface: AppTheme.secondary, onSurface: Colors.white),
                          ),
                          child: child!,
                        ),
                      );
                      if (date != null) setState(() => _selectedDate = date);
                    },
                  ),
                ],
              ),
            ),
          ),
          
          if (!isNew) ...[
            const SizedBox(height: 12),
            // Remove All
            InkWell(
              onTap: () {
                Navigator.pop(context);
                widget.onRemoveAll();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Remove All History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Clear all logs for all seasons', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
