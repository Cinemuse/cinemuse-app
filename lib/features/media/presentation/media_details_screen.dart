import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'dart:async';

import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/features/media/application/play_target.dart';
import 'package:cinemuse_app/shared/widgets/action_feedback.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/features/media/application/media_details_controller.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/tracking_modals.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/watch_logs_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/refresh_user_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
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

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cinemuse_app/features/media/application/series_domain_service_provider.dart';
import 'package:cinemuse_app/features/media/domain/media_details_parts.dart';

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
  void dispose() {
    _mainScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final typeForTmdb = widget.mediaType == 'series' ? 'tv' : widget.mediaType;
    final historyKey = (id: widget.mediaId, type: typeForTmdb);
    final detailsAsync = ref.watch(
      mediaDetailsProvider((id: widget.mediaId, type: typeForTmdb)),
    );
    final controller = ref.read(mediaDetailsControllerProvider.notifier);
    final responsivePadding = AppTheme.getResponsiveHorizontalPadding(context);
    final isMobile = Breakpoints.isCompact(context);
    final isOffline =
        ref.watch(connectivityProvider).value == ConnectivityResult.none;
    // Failed loads get a Retry that loads the details again (REV-206); the
    // provider still turns errors into null (REV-30), hence the generic text.
    Widget loadFailed([Object? error]) => isOffline
        ? OfflinePlaceholder(
            onRetry: () => ref.invalidate(connectivityProvider),
          )
        : OfflinePlaceholder(
            icon: Icons.error_outline_rounded,
            title: l10n.commonError,
            message: error != null
                ? ref.read(errorMapperProvider).map(error).message
                : l10n.failureUnknown,
            onRetry: () => ref.invalidate(
              mediaDetailsProvider((id: widget.mediaId, type: typeForTmdb)),
            ),
          );

    final bodyContent = detailsAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      ),
      error: (err, stack) => loadFailed(err),
      data: (mediaItem) {
        if (mediaItem == null) return loadFailed();

        final tmdbId = mediaItem.tmdbId;
        final isTV = typeForTmdb == 'tv';

        final mediaKind = isTV ? MediaKind.tv : MediaKind.movie;
        bool inList(ListType type) => ref.watch(
          isInSystemListProvider((
            tmdbId: tmdbId,
            mediaType: mediaKind,
            type: type,
          )),
        );
        final isFavorite = inList(ListType.favorites);
        final isInWatchlist = inList(ListType.watchlist);

        final watchHistory = ref
            .watch(mediaWatchHistoryProvider(historyKey))
            .value;
        final playTarget = PlayTarget.fromHistory(watchHistory, isTV: isTV);

        final collection = mediaItem.collection;
        final moreLikeThisList = mediaItem.recommendations ?? const [];

        ref.listen<AsyncValue<WatchHistory?>>(
          mediaWatchHistoryProvider(historyKey),
          (previous, next) {
            final nextHistory = next.value;
            if (!_hasInitializedSeason && nextHistory != null && isTV) {
              _hasInitializedSeason = true;
              final targetSeason = controller.resolveInitialSeason(
                tmdbId: tmdbId,
                series: mediaItem,
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
              series: mediaItem,
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
                  totalEpisodes: ref
                      .read(seriesDomainServiceProvider)
                      .airedEpisodeCount(mediaItem),
                )),
              )
            : null;
        final movieWatchCount = !isTV
            ? ref.watch(movieWatchCountProvider(tmdbId))
            : null;

        final droppedList = ref.watch(droppedListProvider).value;
        final isDropped =
            droppedList?.containsTitle(tmdbId, mediaKind) ?? false;

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
                mediaItem: mediaItem,
                isFavorite: isFavorite,
                isInWatchlist: isInWatchlist,
                onDropClick:
                    (watchHistory != null &&
                        !isDropped &&
                        !watchHistory.isCompleted)
                    ? () => _save(() => controller.dropTitle(watchHistory))
                    : null,
                onClearProgress:
                    (watchHistory != null && watchHistory.progressSeconds > 0)
                    ? () => _save(
                        () => controller.clearProgress(
                          watchHistory,
                          undone: AppSnackBar.showUndo(
                            context,
                            message: l10n.progressCleared(
                              mediaItem.tmdbTitle ?? l10n.commonUnknown,
                            ),
                          ),
                        ),
                      )
                    : null,
                playTarget: playTarget,
                seriesWatchStatus: seriesWatchStatus,
                onPlayClick: () =>
                    _handlePlay(context, playTarget, typeForTmdb),
                onRestartClick: () => _handlePlay(
                  context,
                  playTarget,
                  typeForTmdb,
                  restart: true,
                ),
                onListTap: () => AddToListSheet.show(context, mediaItem),
                onTrackTap: isTV
                    ? () => _showSeriesTrackModal(
                        context,
                        controller,
                        mediaItem,
                        seriesWatchStatus,
                      )
                    : () => _showMovieTrackModal(
                        context,
                        controller,
                        mediaItem,
                        movieWatchCount ?? 0,
                      ),
                onCommentsTap: () =>
                    _handleShowComments(context, mediaItem, isTV, l10n),
                movieWatchCount: movieWatchCount,
                contentPadding: responsivePadding,
              ),
            ),

            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: responsivePadding,
                vertical: isMobile ? 24 : 48,
              ),
              sliver: SliverToBoxAdapter(
                child: isMobile
                    ? _buildMobileLayout(
                        context: context,
                        l10n: l10n,
                        mediaItem: mediaItem,
                        isTV: isTV,
                        typeForTmdb: typeForTmdb,
                        collection: collection,
                        moreLikeThisList: moreLikeThisList,
                      )
                    : _buildWidescreenLayout(
                        context: context,
                        l10n: l10n,
                        mediaItem: mediaItem,
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
            await refreshUserData(context, ref);

            ref.invalidate(
              mediaDetailsProvider((id: widget.mediaId, type: typeForTmdb)),
            );
            ref.invalidate(mediaWatchHistoryProvider(historyKey));
          },
          child: bodyContent,
        ),
      ),
    );
  }

  Widget _buildWidescreenLayout({
    required BuildContext context,
    required AppLocalizations l10n,
    required MediaItem mediaItem,
    required bool isTV,
    required String typeForTmdb,
    required int tmdbId,
    required List<MediaItem> moreLikeThisList,
    required MediaCollection? collection,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSynopsis(context, l10n, mediaItem),
        const SizedBox(height: 32),
        if (isTV && (mediaItem.numberOfSeasons ?? 0) > 0) ...[
          EpisodeSection(mediaId: widget.mediaId, series: mediaItem),
          const SizedBox(height: 32),
        ],
        CastRow(
          cast: mediaItem.cast,
          crew: mediaItem.crew,
          creators: mediaItem.creators,
        ),
        if (VideosRow.hasTrailers(mediaItem.videos)) ...[
          const SizedBox(height: 32),
          VideosRow(videos: mediaItem.videos),
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
        MediaInfoRow(mediaItem: mediaItem, typeForTmdb: typeForTmdb),
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
    required MediaItem mediaItem,
    required bool isTV,
    required String typeForTmdb,
    required MediaCollection? collection,
    required List<MediaItem> moreLikeThisList,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSynopsis(context, l10n, mediaItem),
        const SizedBox(height: 24),
        DetailsTabNav(
          activeTab: _activeTab!,
          onTabChanged: (tab) => setState(() => _activeTab = tab),
          isTV: isTV,
          numberOfSeasons: mediaItem.numberOfSeasons ?? 0,
        ),
        const SizedBox(height: 24),
        _buildMobileTabContent(
          context: context,
          l10n: l10n,
          mediaItem: mediaItem,
          isTV: isTV,
          typeForTmdb: typeForTmdb,
          collection: collection,
          moreLikeThisList: moreLikeThisList,
        ),
      ],
    );
  }

  /// A stop for the arrows and the remote, with nothing to press: the focus
  /// scrolls the whole synopsis on screen, which the buttons above and the
  /// rows below never do.
  Widget _buildSynopsis(
    BuildContext context,
    AppLocalizations l10n,
    MediaItem mediaItem,
  ) {
    return DpadFocusable(
      // The ring follows the box's own corners.
      borderRadius: BorderRadius.circular(
        Breakpoints.isCompact(context) ? 16 : 24,
      ),
      child: BentoBox(
        title: l10n.detailsSynopsis,
        icon: LucideIcons.terminal,
        child: Text(
          mediaItem.overview ?? '',
          style: DesktopTypography.bodyPrimary,
        ),
      ),
    );
  }

  Widget _buildMobileTabContent({
    required BuildContext context,
    required AppLocalizations l10n,
    required MediaItem mediaItem,
    required bool isTV,
    required String typeForTmdb,
    required MediaCollection? collection,
    required List<MediaItem> moreLikeThisList,
  }) {
    switch (_activeTab) {
      case DetailsTab.episodes:
        return isTV
            ? EpisodeSection(mediaId: widget.mediaId, series: mediaItem)
            : const SizedBox.shrink();
      case DetailsTab.cast:
        return CastRow(
          cast: mediaItem.cast,
          crew: mediaItem.crew,
          creators: mediaItem.creators,
          asList: true,
        );
      case DetailsTab.media:
        final hasVideos = VideosRow.hasTrailers(mediaItem.videos);
        final images = mediaItem.images;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (images != null) GalleryBox(images: images),
            if (images != null && hasVideos) const SizedBox(height: 24),
            if (hasVideos) VideosRow(videos: mediaItem.videos, asList: true),
          ],
        );
      case DetailsTab.links:
        return ExternalLinks(
          ids: mediaItem.externalIds,
          homepage: mediaItem.homepage,
          type: typeForTmdb,
          tmdbId: mediaItem.tmdbId,
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
    MediaItem mediaItem,
    bool isTV,
    AppLocalizations l10n,
  ) {
    if (mediaItem.tmdbId > 0) {
      showCommentsBottomSheet(
        context,
        MediaReviewsRequest(
          tmdbId: mediaItem.tmdbId,
          mediaType: isTV ? MediaKind.tv : MediaKind.movie,
          imdbId: mediaItem.imdbId,
          title: mediaItem.titleEn ?? mediaItem.tmdbTitle,
          year: mediaItem.releaseDate?.year,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.detailsTvTimeCommentsNotAvailable)),
      );
    }
  }

  void _handlePlay(
    BuildContext context,
    PlayTarget target,
    String type, {
    bool restart = false,
  }) {
    final tmdbId = int.tryParse(widget.mediaId);
    if (tmdbId != null) {
      final controller = ref.read(mediaDetailsControllerProvider.notifier);
      // Not awaited: the player opens at once; a failure still shows.
      unawaited(
        runShowingErrors(
          context,
          ref,
          () => controller.restoreIfDropped(tmdbId, MediaItem.fromString(type)),
        ),
      );
    }

    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          queryId: widget.mediaId,
          type: type,
          season: target.season,
          episode: target.episode,
          startPosition: restart ? 0 : target.startSeconds,
        ),
      ),
    );
  }

  void _showSeriesTrackModal(
    BuildContext context,
    MediaDetailsController controller,
    MediaItem series,
    ({bool isFullyWatched, bool isPartiallyWatched, int minWatchCount})? status,
  ) {
    if (status == null) return;
    final l10n = AppLocalizations.of(context)!;
    final tmdbId = series.tmdbId;
    final title = series.tmdbTitle ?? l10n.searchSeries;

    SeriesTrackModal.show(
      context: context,
      title: title,
      status: status,
      onMarkRemaining: (date) => _markAll(controller, series, date),
      onMarkAll: (date) =>
          _markAll(controller, series, date, onlyRemaining: false),
      onRemoveAll: () => _save(
        () => controller.deleteAllSeriesLogs(
          tmdbId: tmdbId,
          undone: AppSnackBar.showUndo(
            context,
            message: l10n.watchHistoryRemoved(title),
          ),
        ),
      ),
    );
  }

  void _showMovieTrackModal(
    BuildContext context,
    MediaDetailsController controller,
    MediaItem movie,
    int watchCount,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final tmdbId = movie.tmdbId;
    final title = movie.tmdbTitle ?? l10n.agendaMovie;

    WatchTrackModal.show(
      context: context,
      title: title,
      prompt: l10n.detailsTrackMovieProgress,
      removeAllSubtitle: l10n.detailsClearAllMovieLogs,
      watchCount: watchCount,
      onRewatch: (date) =>
          _save(() => controller.logMovieWatch(tmdbId: tmdbId, loggedAt: date)),
      onRemoveOne: () => _save(
        () => controller.deleteLatestMovieLog(
          tmdbId: tmdbId,
          undone: AppSnackBar.showUndo(
            context,
            message: l10n.oneWatchRemoved(title),
          ),
        ),
      ),
      onRemoveAll: () => _save(
        () => controller.deleteAllMovieLogs(
          tmdbId: tmdbId,
          undone: AppSnackBar.showUndo(
            context,
            message: l10n.watchHistoryRemoved(title),
          ),
        ),
      ),
      onViewHistory: () => WatchLogsSheet.show(context, tmdbId, title),
    );
  }

  Future<bool> _markAll(
    MediaDetailsController controller,
    MediaItem series,
    DateTime? date, {
    bool onlyRemaining = true,
  }) => _save(
    () => controller.markAllEpisodes(
      tmdbId: series.tmdbId,
      series: series,
      onlyRemaining: onlyRemaining,
      loggedAt: date,
    ),
  );

  /// Awaits a save and shows its failure (REV-299).
  Future<bool> _save(Future<void> Function() action) =>
      runShowingErrors(context, ref, action);
}
