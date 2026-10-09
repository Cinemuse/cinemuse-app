import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/application/media_details_controller.dart';
import 'package:cinemuse_app/features/media/application/series_domain_service.dart';
import 'package:cinemuse_app/features/media/domain/comments_repository.dart';
import 'package:cinemuse_app/features/media/domain/episode_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/comments_bottom_sheet.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/episode_carousel_row.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/episode_list.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/tracking_modals.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/watch_logs_sheet.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:cinemuse_app/shared/widgets/bento_box.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

class EpisodeSection extends ConsumerWidget {
  final String mediaId;
  final Map<String, dynamic> details;
  final ScrollController? mainScrollController;

  const EpisodeSection({
    super.key,
    required this.mediaId,
    required this.details,
    this.mainScrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tmdbId = int.parse(mediaId);
    final selectedSeason = ref.watch(selectedSeasonProvider(mediaId));
    final seasonDetailsAsync = ref.watch(
      seasonDetailsProvider((tmdbId: tmdbId, seasonNumber: selectedSeason)),
    );

    final watchedEpisodesMap = ref.watch(watchedEpisodesMapProvider(tmdbId));
    final episodeProgressMap = ref
        .watch(episodeProgressMapProvider(tmdbId))
        .value;
    final controller = ref.read(mediaDetailsControllerProvider.notifier);
    final rawSeasons = details['seasons'] as List? ?? [];
    final seasonSummaries = rawSeasons
        .whereType<Map>()
        .map((s) => SeasonSummary.fromTmdbMap(Map<String, dynamic>.from(s)))
        .where((s) => s.seasonNumber > 0)
        .toList();
    final isMobile = MediaQuery.of(context).size.width < 600;

    void onEpisodeTap(int s, int e, String name, {bool restart = false}) => _handleEpisodePlay(
      context,
      mediaId,
      s,
      e,
      name,
      episodeProgressMap?['$s-$e']?.progressSeconds ?? 0,
      restart: restart,
    );

    void onMarkWatched(int season, int ep, DateTime? date) => controller.logEpisodeWatch(
      tmdbId: tmdbId,
      season: season,
      episode: ep,
      loggedAt: date,
    );

    void onTrackOptions(int season, int ep) => showTrackOptions(
      context: context,
      controller: controller,
      tmdbId: tmdbId,
      season: season,
      episode: ep,
      watchCount: watchedEpisodesMap['$season-$ep'] ?? 0,
    );

    List<({int season, int episode})> onFindMissingPreceding(int season, int ep) =>
        findMissingPrecedingEpisodes(
          ref: ref,
          seasons: rawSeasons,
          watchedEpisodesCount: watchedEpisodesMap,
          currentSeason: season,
          currentEpisode: ep,
        );

    void onShowMarkPrecedingModal(
      int season,
      int ep,
      List<({int season, int episode})> missing,
    ) =>
        showMarkPrecedingModal(
          context: context,
          controller: controller,
          tmdbId: tmdbId,
          season: season,
          episode: ep,
          missing: missing,
        );

    void onViewHistory(int season, int ep) => WatchLogsSheet.show(
      context,
      tmdbId,
      l10n.detailsEpisodeFallback(ep),
      season: season,
      episode: ep,
    );

    void onShowComments(int s, int e) => _showEpisodeComments(
      context,
      tmdbId,
      s,
      e,
      l10n,
    );

    final seasonSelectorWidget = SeasonSelector(
      seasons: seasonSummaries,
      selectedSeason: selectedSeason,
      mediaId: mediaId,
    );

    if (!isMobile) {
      return _buildWidescreenCarousel(
        l10n: l10n,
        selectedSeason: selectedSeason,
        seasonDetailsAsync: seasonDetailsAsync,
        watchedEpisodesMap: watchedEpisodesMap,
        episodeProgressMap: episodeProgressMap,
        seasonSelector: seasonSelectorWidget,
        onEpisodeTap: onEpisodeTap,
        onMarkWatched: onMarkWatched,
        onTrackOptions: onTrackOptions,
        onFindMissingPreceding: onFindMissingPreceding,
        onShowMarkPrecedingModal: onShowMarkPrecedingModal,
        onViewHistory: onViewHistory,
        onShowComments: onShowComments,
      );
    }

    return BentoBox(
      title: l10n.detailsEpisodesRegistry,
      icon: LucideIcons.tv,
      action: seasonSelectorWidget,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 300),
        child: seasonDetailsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.accent,
            ),
          ),
          error: (err, _) => Center(
            child: Text(l10n.detailsErrorLoadingSeason(err.toString())),
          ),
          data: (season) {
            if (season == null) {
              return Center(child: Text(l10n.detailsSeasonNotFound));
            }
            final rawEpisodes = season['episodes'] as List? ?? [];
            final episodes = rawEpisodes
                .whereType<Map>()
                .map((e) => EpisodeItem.fromTmdbMap(
                      Map<String, dynamic>.from(e),
                      seasonNumber: selectedSeason,
                    ))
                .toList();

            return EpisodeList(
              episodes: episodes,
              seasonNumber: selectedSeason,
              mediaId: mediaId,
              watchedEpisodesCount: watchedEpisodesMap,
              episodeProgress: episodeProgressMap,
              onEpisodeTap: onEpisodeTap,
              onMarkWatched: onMarkWatched,
              onTrackOptions: onTrackOptions,
              onFindMissingPreceding: onFindMissingPreceding,
              onShowMarkPrecedingModal: onShowMarkPrecedingModal,
              onViewHistory: onViewHistory,
              onShowComments: onShowComments,
            );
          },
        ),
      ),
    );
  }

  Widget _buildWidescreenCarousel({
    required AppLocalizations l10n,
    required int selectedSeason,
    required AsyncValue<Map<String, dynamic>?> seasonDetailsAsync,
    required Map<String, int> watchedEpisodesMap,
    required Map<String, WatchHistory>? episodeProgressMap,
    required Widget seasonSelector,
    required void Function(int s, int e, String name, {bool restart}) onEpisodeTap,
    required void Function(int season, int ep, DateTime? date) onMarkWatched,
    required void Function(int season, int ep) onTrackOptions,
    required List<({int season, int episode})> Function(int season, int ep) onFindMissingPreceding,
    required void Function(int season, int ep, List<({int season, int episode})> missing) onShowMarkPrecedingModal,
    required void Function(int season, int ep) onViewHistory,
    required void Function(int s, int e) onShowComments,
  }) {
    return seasonDetailsAsync.when(
      loading: () => BentoBox(
        title: l10n.detailsEpisodes,
        icon: Icons.tv,
        action: seasonSelector,
        child: const SizedBox(
          height: 230,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.accent,
            ),
          ),
        ),
      ),
      error: (err, _) => BentoBox(
        title: l10n.detailsEpisodes,
        icon: Icons.tv,
        action: seasonSelector,
        child: SizedBox(
          height: 230,
          child: Center(
            child: Text(l10n.detailsErrorLoadingSeason(err.toString())),
          ),
        ),
      ),
      data: (season) {
        if (season == null) {
          return const SizedBox.shrink();
        }
        final rawEpisodes = season['episodes'] as List? ?? [];
        final episodes = rawEpisodes
            .whereType<Map>()
            .map((e) => EpisodeItem.fromTmdbMap(
                  Map<String, dynamic>.from(e),
                  seasonNumber: selectedSeason,
                ))
            .toList();

        return EpisodeCarouselRow(
          episodes: episodes,
          seasonNumber: selectedSeason,
          mediaId: mediaId,
          watchedEpisodesCount: watchedEpisodesMap,
          episodeProgress: episodeProgressMap,
          seasonSelector: seasonSelector,
          onEpisodeTap: onEpisodeTap,
          onMarkWatched: onMarkWatched,
          onTrackOptions: onTrackOptions,
          onFindMissingPreceding: onFindMissingPreceding,
          onShowMarkPrecedingModal: onShowMarkPrecedingModal,
          onViewHistory: onViewHistory,
          onShowComments: onShowComments,
        );
      },
    );
  }

  static void _handleEpisodePlay(
    BuildContext context,
    String mediaId,
    int season,
    int episode,
    String name,
    int progress, {
    bool restart = false,
  }) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          queryId: mediaId,
          type: 'tv',
          season: season,
          episode: episode,
          episodeTitle: name,
          startPosition: restart ? 0 : progress,
        ),
      ),
    );
  }

  static List<({int season, int episode})> findMissingPrecedingEpisodes({
    required WidgetRef ref,
    required List<dynamic> seasons,
    required Map<String, int> watchedEpisodesCount,
    required int currentSeason,
    required int currentEpisode,
  }) {
    return ref.read(seriesDomainServiceProvider).findMissingPrecedingEpisodes(
      currentSeason: currentSeason,
      currentEpisode: currentEpisode,
      seasons: seasons,
      watchedEpisodesCount: watchedEpisodesCount,
    );
  }

  static void showMarkPrecedingModal({
    required BuildContext context,
    required MediaDetailsController controller,
    required int tmdbId,
    required int season,
    required int episode,
    required List<({int season, int episode})> missing,
  }) {
    MarkPrecedingModal.show(
      context,
      missingCount: missing.length,
    ).then((markAll) {
      if (markAll == null) return;
      if (markAll) {
        final allToMark = [
          ...missing,
          (season: season, episode: episode),
        ];
        controller.logMultipleEpisodes(
          tmdbId: tmdbId,
          episodes: allToMark,
        );
      } else {
        controller.logEpisodeWatch(
          tmdbId: tmdbId,
          season: season,
          episode: episode,
        );
      }
    });
  }

  static void showTrackOptions({
    required BuildContext context,
    required MediaDetailsController controller,
    required int tmdbId,
    required int season,
    required int episode,
    required int watchCount,
  }) {
    TrackOptionsModal.show(
      context: context,
      season: season,
      episode: episode,
      watchCount: watchCount,
      onRewatch: (date) => controller.logEpisodeWatch(
        tmdbId: tmdbId,
        season: season,
        episode: episode,
        loggedAt: date,
      ),
      onRemoveOne: () => controller.deleteLatestEpisodeLog(
        tmdbId: tmdbId,
        season: season,
        episode: episode,
      ),
      onRemoveAll: () => controller.deleteAllEpisodeLogs(
        tmdbId: tmdbId,
        season: season,
        episode: episode,
      ),
      onViewHistory: () => WatchLogsSheet.show(
        context,
        tmdbId,
        'Episode $episode',
        season: season,
        episode: episode,
      ),
    );
  }

  static void _showEpisodeComments(
    BuildContext context,
    int tmdbId,
    int season,
    int episode,
    AppLocalizations l10n,
  ) {
    if (tmdbId > 0) {
      showCommentsBottomSheet(
        context,
        EpisodeCommentsRequest(
          tmdbShowId: tmdbId,
          seasonNumber: season,
          episodeNumber: episode,
        ),
      );
    } else {
      AppSnackBar.show(
        context,
        message: l10n.detailsTvTimeCommentsNotAvailableSeries,
      );
    }
  }
}

class SeasonSelector extends ConsumerWidget {
  final List<SeasonSummary> seasons;
  final int selectedSeason;
  final String mediaId;

  const SeasonSelector({
    super.key,
    required this.seasons,
    required this.selectedSeason,
    required this.mediaId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final popupKey = GlobalKey<PopupMenuButtonState<int>>();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: PopupMenuButton<int>(
        key: popupKey,
        initialValue: selectedSeason,
        onSelected: (val) =>
            ref.read(selectedSeasonProvider(mediaId).notifier).selectSeason(val),
        child: DpadFocusable(
          onTap: () => popupKey.currentState?.showButtonMenu(),
          borderRadius: AppTheme.radiusMd,
          builder: (context, isFocused, isHovered, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isFocused
                    ? theme.focusColor
                    : (isHovered
                        ? theme.hoverColor
                        : theme.colorScheme.surfaceContainer.withValues(alpha: 0.5)),
                borderRadius: AppTheme.radiusMd,
                border: Border.all(
                  color: isFocused
                      ? theme.colorScheme.primary.withValues(alpha: 0.5)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
              child: child,
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  l10n.detailsSeasonNumber(selectedSeason),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_down,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
        itemBuilder: (context) => seasons
            .map(
              (s) => PopupMenuItem<int>(
                value: s.seasonNumber,
                child: Text(
                  l10n.detailsSeasonNumber(s.seasonNumber),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
