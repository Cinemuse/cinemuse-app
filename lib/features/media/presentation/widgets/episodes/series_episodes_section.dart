import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/domain/comments_repository.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/comments_bottom_sheet.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episode_carousel_row.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episode_list.dart';
import 'package:cinemuse_app/features/media/application/media_details_controller.dart';
import 'package:cinemuse_app/features/media/application/series_domain_service.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/tracking_modals.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/watch_logs_sheet.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/bento_box.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

class SeriesEpisodesSection extends ConsumerWidget {
  final String mediaId;
  final Map<String, dynamic> details;
  final ScrollController? mainScrollController;

  const SeriesEpisodesSection({
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
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (!isMobile) {
      return _buildBigPictureCarousel(
        context: context,
        ref: ref,
        l10n: l10n,
        selectedSeason: selectedSeason,
        seasonDetailsAsync: seasonDetailsAsync,
        watchedEpisodesMap: watchedEpisodesMap,
        episodeProgressMap: episodeProgressMap,
        tmdbId: tmdbId,
      );
    }

    return BentoBox(
      title: l10n.detailsEpisodesRegistry,
      icon: LucideIcons.tv,
      action: SeasonSelector(
        media: details,
        selectedSeason: selectedSeason,
        mediaId: mediaId,
      ),
      child: ConstrainedBox(
        constraints: isMobile
            ? const BoxConstraints(minHeight: 300)
            : const BoxConstraints(minHeight: 500, maxHeight: 500),
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
            final episodes = season['episodes'] as List? ?? [];
            final initialIndex = _calculateInitialEpisodeIndex(
              episodes,
              selectedSeason,
              watchedEpisodesMap,
            );

            return EpisodeList(
              episodes: episodes,
              seasonNumber: selectedSeason,
              media: details,
              watchedEpisodesCount: watchedEpisodesMap,
              initialScrollIndex: initialIndex,
              mainScrollController: mainScrollController,
              onShowComments: (season, episode) => _showEpisodeComments(
                context,
                details,
                mediaId,
                season,
                episode,
                l10n,
              ),
              onEpisodeTap: (s, e, name, {bool restart = false}) => _handleEpisodePlay(
                context,
                mediaId,
                s,
                e,
                name,
                episodeProgressMap?['$s-$e']?.progressSeconds ?? 0,
                restart: restart,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBigPictureCarousel({
    required BuildContext context,
    required WidgetRef ref,
    required AppLocalizations l10n,
    required int selectedSeason,
    required AsyncValue<Map<String, dynamic>?> seasonDetailsAsync,
    required Map<String, int> watchedEpisodesMap,
    required Map<String, WatchHistory>? episodeProgressMap,
    required int tmdbId,
  }) {
    final controller = ref.read(mediaDetailsControllerProvider.notifier);
    final seasons = details['seasons'] as List? ?? [];

    return seasonDetailsAsync.when(
      loading: () => BentoBox(
        title: l10n.detailsEpisodes,
        icon: Icons.tv,
        action: SeasonSelector(
          media: details,
          selectedSeason: selectedSeason,
          mediaId: mediaId,
        ),
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
        action: SeasonSelector(
          media: details,
          selectedSeason: selectedSeason,
          mediaId: mediaId,
        ),
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
        final episodes = season['episodes'] as List? ?? [];
        return EpisodeCarouselRow(
          episodes: episodes,
          seasonNumber: selectedSeason,
          mediaId: mediaId,
          watchedEpisodesCount: watchedEpisodesMap,
          episodeProgress: episodeProgressMap,
          seasonSelector: SeasonSelector(
            media: details,
            selectedSeason: selectedSeason,
            mediaId: mediaId,
          ),
          onEpisodeTap: (s, e, name, {bool restart = false}) => _handleEpisodePlay(
            context,
            mediaId,
            s,
            e,
            name,
            episodeProgressMap?['$s-$e']?.progressSeconds ?? 0,
            restart: restart,
          ),
          onMarkWatched: (season, ep, date) {
            controller.logEpisodeWatch(
              tmdbId: tmdbId,
              season: season,
              episode: ep,
              loggedAt: date,
            );
          },
          onTrackOptions: (season, ep) {
            final watchCount = watchedEpisodesMap['$season-$ep'] ?? 0;
            showTrackOptions(
              context: context,
              controller: controller,
              tmdbId: tmdbId,
              season: season,
              episode: ep,
              watchCount: watchCount,
            );
          },
          onFindMissingPreceding: (season, ep) => findMissingPrecedingEpisodes(
            ref: ref,
            seasons: seasons,
            watchedEpisodesCount: watchedEpisodesMap,
            currentSeason: season,
            currentEpisode: ep,
          ),
          onShowMarkPrecedingModal: (season, ep, missing) => showMarkPrecedingModal(
            context: context,
            controller: controller,
            tmdbId: tmdbId,
            season: season,
            episode: ep,
            missing: missing,
          ),
          onShowComments: (s, e) => _showEpisodeComments(
            context,
            details,
            mediaId,
            s,
            e,
            l10n,
          ),
        );
      },
    );
  }

  static int _calculateInitialEpisodeIndex(
    List<dynamic> episodes,
    int selectedSeason,
    Map<String, int> watchedEpisodesMap,
  ) {
    if (watchedEpisodesMap.isEmpty) return 0;
    for (int i = 0; i < episodes.length; i++) {
      final ep = episodes[i];
      final epNum = ep['episode_number'] as int? ?? 0;
      final key = '$selectedSeason-$epNum';
      if ((watchedEpisodesMap[key] ?? 0) == 0) {
        return i;
      }
    }
    return 0;
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
    Map<String, dynamic> details,
    String mediaId,
    int season,
    int episode,
    AppLocalizations l10n,
  ) {
    final int tmdbId = details['id'] is int
        ? details['id']
        : int.tryParse(details['id']?.toString() ?? '') ??
            int.tryParse(mediaId) ??
            0;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.detailsTvTimeCommentsNotAvailableSeries,
          ),
        ),
      );
    }
  }
}

class SeasonSelector extends ConsumerWidget {
  final Map<String, dynamic> media;
  final int selectedSeason;
  final String mediaId;

  const SeasonSelector({
    super.key,
    required this.media,
    required this.selectedSeason,
    required this.mediaId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final seasons = (media['seasons'] as List? ?? [])
        .where((s) => (s['season_number'] as int? ?? 0) > 0)
        .toList();

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
          borderRadius: BorderRadius.circular(8),
          builder: (context, isFocused, isHovered, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isFocused
                    ? theme.focusColor
                    : (isHovered
                        ? theme.hoverColor
                        : theme.colorScheme.surfaceContainer.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(8),
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
                value: s['season_number'] as int,
                child: Text(
                  l10n.detailsSeasonNumber(s['season_number']),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
