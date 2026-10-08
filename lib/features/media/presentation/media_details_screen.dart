import 'package:cinemuse_app/core/error/app_exception.dart';
import 'package:cinemuse_app/features/media/application/media_details_controller.dart';
import 'package:cinemuse_app/features/media/application/series_domain_service.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/tracking_modals.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/watch_logs_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/application/display_mode_provider.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/hero/details_hero.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/episode_section.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/cast_row.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/videos_row.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/external_links.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/comments_bottom_sheet.dart';
import 'package:cinemuse_app/features/media/domain/comments_repository.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/add_to_list_sheet.dart';
import 'package:cinemuse_app/shared/widgets/bento_box.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/details_tab_nav.dart';
import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:cinemuse_app/shared/widgets/offline_banner.dart';
import 'package:cinemuse_app/shared/widgets/offline_placeholder.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/collection_tile.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/media_list_row.dart';
import 'package:cinemuse_app/shared/widgets/carousels/generic_carousel_row.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/gallery_box.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/media_info_row.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/home/application/home_providers.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
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
  DetailsTab? _activeTab;
  final ScrollController _mainScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mainScrollController.hasClients && _mainScrollController.offset > 0) {
        _mainScrollController.jumpTo(0.0);
      }
    });
  }

  @override
  void dispose() {
    _mainScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final typeForTmdb = widget.mediaType == 'series' ? 'tv' : widget.mediaType;
    final detailsAsync = ref.watch(
      mediaDetailsProvider((id: widget.mediaId, type: typeForTmdb)),
    );
    final controller = ref.read(mediaDetailsControllerProvider.notifier);
    final responsivePadding = AppTheme.getResponsiveHorizontalPadding(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final connectivity = ref.watch(connectivityProvider);
    final isOffline = connectivity.valueOrNull == ConnectivityResult.none;
    final isBigPicture = ref.watch(isBigPictureProvider);

    final bodyContent = detailsAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      ),
      error: (err, stack) {
        if (isOffline) {
          return OfflinePlaceholder(
            onRetry: () => ref.invalidate(connectivityProvider),
          );
        }
        final message = err is AppException ? err.message : err.toString();
        return Center(
          child: Text(
            '${l10n.commonError}: $message',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
        );
      },
      data: (details) {
        if (details == null) {
          if (isOffline) {
            return OfflinePlaceholder(
              onRetry: () => ref.invalidate(connectivityProvider),
            );
          }
          return Center(
            child: Text(
              l10n.commonError,
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
          );
        }

        final tmdbId = int.parse(widget.mediaId);
        final isTV = typeForTmdb == 'tv';

        // Track list status
        final mediaKind = isTV ? MediaKind.tv : MediaKind.movie;
        final isFavorite = ref
            .watch(userListsProvider.notifier)
            .isFavorite(tmdbId, mediaKind);
        final isInWatchlist = ref
            .watch(userListsProvider.notifier)
            .isInWatchlist(tmdbId, mediaKind);

        // Watch history data
        final watchHistory = ref
            .watch(mediaWatchHistoryProvider(widget.mediaId))
            .value;

        final collection = details['belongs_to_collection'];
        final recommendations =
            details['recommendations']?['results'] as List? ?? [];
        final moreLikeThisList = recommendations
            .map((item) => MediaItem.fromTmdbMap(Map<String, dynamic>.from(item as Map)))
            .toList();

        // Auto-select season based on history
        ref.listen<AsyncValue<WatchHistory?>>(
          mediaWatchHistoryProvider(widget.mediaId),
          (previous, next) {
            final nextHistory = next.value;
            if (!_hasInitializedSeason && nextHistory != null && isTV) {
              _hasInitializedSeason = true;
              final targetSeason = controller.resolveInitialSeason(
                tmdbId: tmdbId,
                details: details,
                watchHistory: nextHistory,
              );
              ref
                  .read(selectedSeasonProvider(widget.mediaId).notifier)
                  .selectSeason(targetSeason);
            }
          },
        );

        if (!_hasInitializedSeason && watchHistory != null && isTV) {
          _hasInitializedSeason = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final targetSeason = controller.resolveInitialSeason(
              tmdbId: tmdbId,
              details: details,
              watchHistory: watchHistory,
            );
            ref
                .read(selectedSeasonProvider(widget.mediaId).notifier)
                .selectSeason(targetSeason);
          });
        }

        final seriesWatchStatus = isTV
            ? ref.watch(
                seriesWatchStatusProvider((
                  tmdbId: tmdbId,
                  totalEpisodes: _calculateReleasedEpisodes(details),
                )),
              )
            : null;
        final movieWatchCount = !isTV
            ? ref.watch(movieWatchCountProvider(tmdbId))
            : 0;

        final droppedList = ref.watch(droppedListProvider).valueOrNull;
        final isDropped = droppedList?.items.any((i) => i.tmdbId == tmdbId) ?? false;

        // Set default tab if not set
        _activeTab ??= isTV ? DetailsTab.episodes : DetailsTab.cast;

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: _mainScrollController,
          slivers: [
            if (isOffline)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    responsivePadding,
                    48,
                    responsivePadding,
                    0,
                  ),
                  child: OfflineBanner(
                    onRetry: () => ref.invalidate(connectivityProvider),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: DetailsHero(
                media: {'id': widget.mediaId, 'type': typeForTmdb},
                details: details,
                isFavorite: isFavorite,
                isInWatchlist: isInWatchlist,
                onDropClick: (watchHistory != null && !isDropped && !watchHistory.isCompleted)
                    ? () async {
                        final user = ref.read(authProvider).value;
                        if (user != null) {
                          await ref.read(watchHistoryRepositoryProvider)
                              .dropFromContinueWatching(user.id, tmdbId);
                          ref.invalidate(droppedListProvider);
                          ref.invalidate(continueWatchingProvider);
                        }
                      }
                    : null,
                onClearProgress: (watchHistory != null && watchHistory.progressSeconds > 0)
                    ? () async {
                        final user = ref.read(authProvider).value;
                        if (user != null) {
                          await ref.read(watchHistoryRepositoryProvider).clearProgress(
                            userId: user.id,
                            tmdbId: tmdbId,
                            mediaType: typeForTmdb,
                          );
                          ref.invalidate(continueWatchingProvider);
                        }
                      }
                    : null,
                resumeData: (watchHistory != null && !watchHistory.isCompleted)
                    ? {
                        // map 'tv' mediaType to 'tv' string to ensure DetailsHero picks it up
                        'type':
                            (watchHistory.mediaType == MediaKind.episode ||
                                watchHistory.mediaType == MediaKind.tv)
                            ? 'tv'
                            : 'movie',
                        'season': watchHistory.season,
                        'episode': watchHistory.episode,
                        'progress': watchHistory.progressSeconds,
                      }
                    : null,
                seriesWatchStatus: seriesWatchStatus,
                onPlayClick: () =>
                    _handlePlay(context, watchHistory, typeForTmdb),
                onRestartClick: () => _handlePlay(
                  context,
                  watchHistory,
                  typeForTmdb,
                  restart: true,
                ),
                onListTap: () =>
                    _showAddToList(context, tmdbId, typeForTmdb, details),
                onTrackTap: isTV
                    ? () => _showSeriesTrackModal(
                        context,
                        controller,
                        tmdbId,
                        details,
                        seriesWatchStatus,
                      )
                    : () => _showMovieTrackModal(
                        context,
                        controller,
                        tmdbId,
                        details,
                        movieWatchCount,
                      ),
                onCommentsTap: () =>
                    _handleShowComments(context, details, isTV, l10n),
                movieWatchCount: movieWatchCount,
                contentPadding: responsivePadding,
              ),
            ),

            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: responsivePadding,
                vertical: isBigPicture ? 16 : (isMobile ? 24 : 48),
              ),
              sliver: SliverToBoxAdapter(
                child: isMobile
                    ? _buildMobileLayout(
                        context: context,
                        l10n: l10n,
                        details: details,
                        isTV: isTV,
                        typeForTmdb: typeForTmdb,
                        collection: collection,
                        moreLikeThisList: moreLikeThisList,
                      )
                    : _buildWidescreenLayout(
                        context: context,
                        l10n: l10n,
                        details: details,
                        isTV: isTV,
                        typeForTmdb: typeForTmdb,
                        tmdbId: tmdbId,
                        moreLikeThisList: moreLikeThisList,
                        collection: collection,
                      ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.gameButtonB ||
              event.logicalKey == LogicalKeyboardKey.goBack) {
            Navigator.of(context).maybePop();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: AppTheme.primary,
        body: RefreshIndicator(
          color: AppTheme.accent,
          backgroundColor: AppTheme.secondary,
          onRefresh: () async {
            final user = ref.read(authProvider).value;
            if (user != null) {
              await Future.wait([
                ref.read(watchHistoryRepositoryProvider).syncWatchHistory(user.id),
                ref.read(listsRepositoryProvider).syncUserLists(user.id),
              ]).catchError((_) => []);
            }

            ref.invalidate(mediaDetailsProvider((id: widget.mediaId, type: typeForTmdb)));
            ref.invalidate(mediaWatchHistoryProvider(widget.mediaId));
          },
          child: bodyContent,
        ),
      ),
    );
  }

  Widget _buildWidescreenLayout({
    required BuildContext context,
    required AppLocalizations l10n,
    required Map<String, dynamic> details,
    required bool isTV,
    required String typeForTmdb,
    required int tmdbId,
    required List<MediaItem> moreLikeThisList,
    required dynamic collection,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BentoBox(
          title: l10n.detailsSynopsis,
          icon: LucideIcons.terminal,
          child: Text(
            details['overview'] ?? '',
            style: DesktopTypography.bodyPrimary,
          ),
        ),
        const SizedBox(height: 32),
        if (isTV && (details['number_of_seasons'] ?? 0) > 0) ...[
          EpisodeSection(
            mediaId: widget.mediaId,
            details: details,
            mainScrollController: _mainScrollController,
          ),
          const SizedBox(height: 32),
        ],
        CastRow(credits: details['credits'], details: details),
        if (VideosRow.hasTrailers(details['videos'])) ...[
          const SizedBox(height: 32),
          VideosRow(videos: details['videos']),
        ],
        if (moreLikeThisList.isNotEmpty) ...[
          const SizedBox(height: 32),
          MediaListRow(
            title: l10n.detailsMoreLikeThis,
            icon: LucideIcons.sparkles,
            items: moreLikeThisList,
            theme: CarouselTheme.bentoBox,
          ),
        ],
        const SizedBox(height: 32),
        MediaInfoRow(
          details: details,
          typeForTmdb: typeForTmdb,
        ),
        if (collection != null) ...[
          const SizedBox(height: 32),
          BentoBox(
            title: l10n.detailsCollection,
            icon: LucideIcons.film,
            child: CollectionTile(collection: collection),
          ),
        ],
      ],
    );
  }

  Widget _buildMobileLayout({
    required BuildContext context,
    required AppLocalizations l10n,
    required Map<String, dynamic> details,
    required bool isTV,
    required String typeForTmdb,
    required dynamic collection,
    required List<MediaItem> moreLikeThisList,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BentoBox(
          title: l10n.detailsSynopsis,
          icon: LucideIcons.terminal,
          child: Text(
            details['overview'] ?? '',
            style: DesktopTypography.bodyPrimary,
          ),
        ),
        const SizedBox(height: 24),
        DetailsTabNav(
          activeTab: _activeTab!,
          onTabChanged: (tab) => setState(() => _activeTab = tab),
          isTV: isTV,
          numberOfSeasons: details['number_of_seasons'] ?? 0,
        ),
        const SizedBox(height: 24),
        _buildMobileTabContent(
          context: context,
          l10n: l10n,
          details: details,
          isTV: isTV,
          typeForTmdb: typeForTmdb,
          collection: collection,
          moreLikeThisList: moreLikeThisList,
        ),
      ],
    );
  }

  Widget _buildMobileTabContent({
    required BuildContext context,
    required AppLocalizations l10n,
    required Map<String, dynamic> details,
    required bool isTV,
    required String typeForTmdb,
    required dynamic collection,
    required List<MediaItem> moreLikeThisList,
  }) {
    switch (_activeTab) {
      case DetailsTab.episodes:
        return isTV
            ? EpisodeSection(
                mediaId: widget.mediaId,
                details: details,
                mainScrollController: _mainScrollController,
              )
            : const SizedBox.shrink();
      case DetailsTab.cast:
        return CastRow(credits: details['credits'], details: details);
      case DetailsTab.media:
        final hasVideos = VideosRow.hasTrailers(details['videos']);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasVideos) ...[
              VideosRow(videos: details['videos']),
              const SizedBox(height: 24),
            ],
            GalleryBox(details: details),
          ],
        );
      case DetailsTab.links:
        return ExternalLinks(
          externalIds: details['external_ids'],
          homepage: details['homepage'],
          type: typeForTmdb,
          tmdbId: details['id'],
        );
      case DetailsTab.more:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (collection != null) ...[
              BentoBox(
                title: l10n.detailsCollection,
                icon: LucideIcons.film,
                child: CollectionTile(collection: collection),
              ),
              if (moreLikeThisList.isNotEmpty) const SizedBox(height: 24),
            ],
            if (moreLikeThisList.isNotEmpty)
              MediaListRow(
                title: l10n.detailsMoreLikeThis,
                icon: LucideIcons.sparkles,
                items: moreLikeThisList,
                theme: CarouselTheme.bentoBox,
              ),
          ],
        );
      case null:
        return const SizedBox.shrink();
    }
  }

  void _handleShowComments(
    BuildContext context,
    Map<String, dynamic> details,
    bool isTV,
    AppLocalizations l10n,
  ) {
    final int tmdbId = details['id'] is int
        ? details['id']
        : int.tryParse(details['id']?.toString() ?? '') ?? 0;
    final String? imdbId =
        (details['external_ids']?['imdb_id'] ?? details['imdb_id'])?.toString();
    if (tmdbId > 0) {
      showCommentsBottomSheet(
        context,
        MediaReviewsRequest(
          tmdbId: tmdbId,
          mediaType: isTV ? MediaKind.tv : MediaKind.movie,
          imdbId: imdbId,
          title: _resolveEnglishOrOriginalTitle(details),
          year: DateTime.tryParse(
            details['release_date']?.toString() ??
                details['first_air_date']?.toString() ??
                '',
          )?.year,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.detailsTvTimeCommentsNotAvailable,
          ),
        ),
      );
    }
  }

  void _handlePlay(
    BuildContext context,
    WatchHistory? watchHistory,
    String type, {
    bool restart = false,
  }) {
    int? season;
    int? episode;

    if (type == 'tv') {
      season = watchHistory?.season ?? 1;
      episode = watchHistory?.episode ?? 1;
    }

    // Implicit restore if dropped
    final tmdbId = int.tryParse(widget.mediaId);
    if (tmdbId != null) {
      final droppedList = ref.read(droppedListProvider).valueOrNull;
      final isDropped = droppedList?.items.any((i) => i.tmdbId == tmdbId) ?? false;
      if (isDropped) {
        final user = ref.read(authProvider).value;
        if (user != null) {
          ref.read(watchHistoryRepositoryProvider).restoreToContinueWatching(user.id, tmdbId).then((_) {
            ref.invalidate(droppedListProvider);
            ref.invalidate(continueWatchingProvider);
          });
        }
      }
    }

    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          queryId: widget.mediaId,
          type: type,
          season: season,
          episode: episode,
          startPosition: restart ? 0 : (watchHistory?.progressSeconds ?? 0),
        ),
      ),
    );
  }

  void _showAddToList(
    BuildContext context,
    int tmdbId,
    String type,
    Map<String, dynamic> details,
  ) {
    final mediaItem = MediaItem.fromTmdbDetails(
      {...details, 'id': tmdbId}, // Ensure id is present in details
      MediaItem.fromString(type),
    );

    AddToListSheet.show(context, mediaItem);
  }

  void _showSeriesTrackModal(
    BuildContext context,
    MediaDetailsController controller,
    int tmdbId,
    Map<String, dynamic> details,
    ({bool isFullyWatched, bool isPartiallyWatched, int minWatchCount})? status,
  ) {
    if (status == null) return;
    final l10n = AppLocalizations.of(context)!;

    SeriesTrackModal.show(
      context: context,
      title: details['name'] ?? l10n.searchSeries,
      status: status,
      onMarkRemaining: (date) => _markAllEpisodes(
        controller,
        tmdbId,
        details,
        date,
        onlyRemaining: true,
      ),
      onMarkAll: (date) => _markAllEpisodes(
        controller,
        tmdbId,
        details,
        date,
        onlyRemaining: false,
      ),
      onRemoveAll: () => controller.deleteAllSeriesLogs(tmdbId: tmdbId),
    );
  }

  void _showMovieTrackModal(
    BuildContext context,
    MediaDetailsController controller,
    int tmdbId,
    Map<String, dynamic> details,
    int watchCount,
  ) {
    final l10n = AppLocalizations.of(context)!;
    // Provide a fallback title just in case
    final title = details['title'] ?? details['name'] ?? l10n.agendaMovie;

    MovieTrackModal.show(
      context: context,
      title: title,
      watchCount: watchCount,
      onRewatch: (date) =>
          controller.logMovieWatch(tmdbId: tmdbId, loggedAt: date),
      onRemoveOne: () => controller.deleteLatestMovieLog(tmdbId: tmdbId),
      onRemoveAll: () => controller.deleteAllMovieLogs(tmdbId: tmdbId),
      onViewHistory: () => WatchLogsSheet.show(
        context,
        tmdbId,
        title,
      ),
    );
  }

  void _markAllEpisodes(
    MediaDetailsController controller,
    int tmdbId,
    Map<String, dynamic> details,
    DateTime? date, {
    required bool onlyRemaining,
  }) {
    final List<({int season, int episode})> episodesToMark = [];
    final seasons = details['seasons'] as List? ?? [];

    final watchedMap = ref.read(watchedEpisodesMapProvider(tmdbId));
    final now = DateTime.now();
    final lastAired = details['last_episode_to_air'];

    for (var season in seasons) {
      final sNum = season['season_number'] as int? ?? 0;
      if (sNum == 0) continue;

      if (season['air_date'] == null) continue;
      final airDate = DateTime.tryParse(season['air_date'].toString());
      if (airDate == null || airDate.isAfter(now)) continue;

      int epCount = 0;
      if (lastAired != null && sNum == lastAired['season_number']) {
        epCount = (lastAired['episode_number'] as int? ?? 0);
      } else if (lastAired == null ||
          sNum < (lastAired['season_number'] as int? ?? 0)) {
        epCount = season['episode_count'] as int? ?? 0;
      }

      for (int e = 1; e <= epCount; e++) {
        if (onlyRemaining && (watchedMap['$sNum-$e'] ?? 0) > 0) continue;
        episodesToMark.add((season: sNum, episode: e));
      }
    }

    if (episodesToMark.isEmpty) return;
    controller.logMultipleEpisodes(
      tmdbId: tmdbId,
      episodes: episodesToMark,
      loggedAt: date,
    );
  }

  int _calculateReleasedEpisodes(Map<String, dynamic> details) {
    return ref.read(seriesDomainServiceProvider).calculateReleasedEpisodes(details);
  }

  String? _resolveEnglishOrOriginalTitle(Map<String, dynamic> details) {
    return MediaItem.extractTitleFromTmdb(details, 'en') ??
        details['original_title']?.toString() ??
        details['title']?.toString() ??
        details['name']?.toString();
  }
}
