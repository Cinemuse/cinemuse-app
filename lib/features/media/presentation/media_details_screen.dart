import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'dart:async';

import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/features/media/application/play_target.dart';
import 'package:cinemuse_app/shared/widgets/action_feedback.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/features/media/application/media_details_controller.dart';
import 'package:cinemuse_app/features/media/application/series_domain_service.dart';
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
      typedMediaDetailsProvider((id: widget.mediaId, type: typeForTmdb)),
    );
    final controller = ref.read(mediaDetailsControllerProvider.notifier);
    final responsivePadding = AppTheme.getResponsiveHorizontalPadding(context);
    final isMobile = Breakpoints.isCompact(context);
    final isOffline =
        ref.watch(connectivityProvider).valueOrNull == ConnectivityResult.none;
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

        final rawDetails = mediaItem.rawTmdbData ?? {};
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
        final recommendations =
            rawDetails['recommendations']?['results'] as List? ?? [];
        final moreLikeThisList = recommendations
            .map(
              (item) =>
                  MediaItem.fromTmdbMap(Map<String, dynamic>.from(item as Map)),
            )
            .toList();

        ref.listen<AsyncValue<WatchHistory?>>(
          mediaWatchHistoryProvider(historyKey),
          (previous, next) {
            final nextHistory = next.value;
            if (!_hasInitializedSeason && nextHistory != null && isTV) {
              _hasInitializedSeason = true;
              final targetSeason = controller.resolveInitialSeason(
                tmdbId: tmdbId,
                details: rawDetails,
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
              details: rawDetails,
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
                      .airedEpisodeCount(rawDetails),
                )),
              )
            : null;
        final movieWatchCount = !isTV
            ? ref.watch(movieWatchCountProvider(tmdbId))
            : null;

        final droppedList = ref.watch(droppedListProvider).valueOrNull;
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
                details: rawDetails,
                isFavorite: isFavorite,
                isInWatchlist: isInWatchlist,
                onDropClick:
                    (watchHistory != null &&
                        !isDropped &&
                        !watchHistory.isCompleted)
                    ? () => runShowingErrors(
                        context,
                        ref,
                        () => controller.dropTitle(watchHistory),
                      )
                    : null,
                onClearProgress:
                    (watchHistory != null && watchHistory.progressSeconds > 0)
                    ? () => runShowingErrors(
                        context,
                        ref,
                        () => controller.clearProgress(watchHistory),
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
                onListTap: () =>
                    _showAddToList(context, tmdbId, typeForTmdb, rawDetails),
                onTrackTap: isTV
                    ? () => _showSeriesTrackModal(
                        context,
                        controller,
                        tmdbId,
                        rawDetails,
                        seriesWatchStatus,
                      )
                    : () => _showMovieTrackModal(
                        context,
                        controller,
                        tmdbId,
                        rawDetails,
                        movieWatchCount ?? 0,
                      ),
                onCommentsTap: () =>
                    _handleShowComments(context, rawDetails, isTV, l10n),
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
                        details: rawDetails,
                        isTV: isTV,
                        typeForTmdb: typeForTmdb,
                        collection: collection,
                        moreLikeThisList: moreLikeThisList,
                      )
                    : _buildWidescreenLayout(
                        context: context,
                        l10n: l10n,
                        mediaItem: mediaItem,
                        details: rawDetails,
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
    required Map<String, dynamic> details,
    required bool isTV,
    required String typeForTmdb,
    required int tmdbId,
    required List<MediaItem> moreLikeThisList,
    required MediaCollection? collection,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BentoBox(
          title: l10n.detailsSynopsis,
          icon: LucideIcons.terminal,
          child: Text(
            mediaItem.overview ?? details['overview'] ?? '',
            style: DesktopTypography.bodyPrimary,
          ),
        ),
        const SizedBox(height: 32),
        if (isTV &&
            (mediaItem.numberOfSeasons ?? details['number_of_seasons'] ?? 0) >
                0) ...[
          EpisodeSection(mediaId: widget.mediaId, details: details),
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
    required Map<String, dynamic> details,
    required bool isTV,
    required String typeForTmdb,
    required MediaCollection? collection,
    required List<MediaItem> moreLikeThisList,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BentoBox(
          title: l10n.detailsSynopsis,
          icon: LucideIcons.terminal,
          child: Text(
            mediaItem.overview ?? details['overview'] ?? '',
            style: DesktopTypography.bodyPrimary,
          ),
        ),
        const SizedBox(height: 24),
        DetailsTabNav(
          activeTab: _activeTab!,
          onTabChanged: (tab) => setState(() => _activeTab = tab),
          isTV: isTV,
          numberOfSeasons:
              mediaItem.numberOfSeasons ?? details['number_of_seasons'] ?? 0,
        ),
        const SizedBox(height: 24),
        _buildMobileTabContent(
          context: context,
          l10n: l10n,
          mediaItem: mediaItem,
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
    required MediaItem mediaItem,
    required Map<String, dynamic> details,
    required bool isTV,
    required String typeForTmdb,
    required MediaCollection? collection,
    required List<MediaItem> moreLikeThisList,
  }) {
    switch (_activeTab) {
      case DetailsTab.episodes:
        return isTV
            ? EpisodeSection(mediaId: widget.mediaId, details: details)
            : const SizedBox.shrink();
      case DetailsTab.cast:
        return CastRow(
          cast: mediaItem.cast,
          crew: mediaItem.crew,
          creators: mediaItem.creators,
        );
      case DetailsTab.media:
        final hasVideos = VideosRow.hasTrailers(mediaItem.videos);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasVideos) ...[
              VideosRow(videos: mediaItem.videos),
              const SizedBox(height: 24),
            ],
            if (mediaItem.images != null) GalleryBox(images: mediaItem.images!),
          ],
        );
      case DetailsTab.links:
        return ExternalLinks(
          ids: mediaItem.externalIds,
          homepage: mediaItem.homepage ?? details['homepage'],
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
      onMarkRemaining: (date) => _markAll(controller, tmdbId, details, date),
      onMarkAll: (date) =>
          _markAll(controller, tmdbId, details, date, onlyRemaining: false),
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
    final title = details['title'] ?? details['name'] ?? l10n.agendaMovie;

    MovieTrackModal.show(
      context: context,
      title: title,
      watchCount: watchCount,
      onRewatch: (date) =>
          controller.logMovieWatch(tmdbId: tmdbId, loggedAt: date),
      onRemoveOne: () => controller.deleteLatestMovieLog(tmdbId: tmdbId),
      onRemoveAll: () => controller.deleteAllMovieLogs(tmdbId: tmdbId),
      onViewHistory: () => WatchLogsSheet.show(context, tmdbId, title),
    );
  }

  Future<bool> _markAll(
    MediaDetailsController controller,
    int tmdbId,
    Map<String, dynamic> details,
    DateTime? date, {
    bool onlyRemaining = true,
  }) => runShowingErrors(
    context,
    ref,
    () => controller.markAllEpisodes(
      tmdbId: tmdbId,
      details: details,
      onlyRemaining: onlyRemaining,
      loggedAt: date,
    ),
  );

  String? _resolveEnglishOrOriginalTitle(Map<String, dynamic> details) {
    return MediaItem.extractTitleFromTmdb(details, 'en') ??
        details['original_title']?.toString() ??
        details['title']?.toString() ??
        details['name']?.toString();
  }
}
