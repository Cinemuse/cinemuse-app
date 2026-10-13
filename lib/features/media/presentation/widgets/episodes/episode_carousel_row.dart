import 'package:cinemuse_app/features/media/application/series_domain_service.dart';
import 'package:cinemuse_app/features/media/domain/episode_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/episode_carousel_card.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/carousels/generic_carousel_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A horizontal carousel row of episodes for a TV series season.
class EpisodeCarouselRow extends ConsumerWidget {
  final List<EpisodeItem> episodes;
  final int seasonNumber;
  final String mediaId;
  final Map<String, int> watchedEpisodesCount;
  final Map<String, WatchHistory>? episodeProgress;
  final Widget? seasonSelector;

  /// Shown inside the row (header kept) when [episodes] is empty.
  final WidgetBuilder? emptyBuilder;
  final void Function(int season, int episode, String name, {bool restart})?
  onEpisodeTap;
  final Function(int season, int episode, DateTime? date)? onMarkWatched;
  final Function(int season, int episode)? onTrackOptions;
  final List<({int season, int episode})> Function(int season, int episode)?
  onFindMissingPreceding;
  final Function(
    int season,
    int episode,
    List<({int season, int episode})> missing,
  )?
  onShowMarkPrecedingModal;
  final void Function(int season, int episode)? onShowComments;
  final Function(int season, int episode)? onViewHistory;

  const EpisodeCarouselRow({
    super.key,
    required this.episodes,
    required this.seasonNumber,
    required this.mediaId,
    this.watchedEpisodesCount = const {},
    this.episodeProgress,
    this.seasonSelector,
    this.emptyBuilder,
    this.onEpisodeTap,
    this.onMarkWatched,
    this.onTrackOptions,
    this.onFindMissingPreceding,
    this.onShowMarkPrecedingModal,
    this.onShowComments,
    this.onViewHistory,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final seriesDomainService = ref.watch(seriesDomainServiceProvider);

    return GenericCarouselRow(
      title: l10n.detailsEpisodes,
      icon: Icons.tv,
      theme: CarouselTheme.bentoBox,
      headerAction: seasonSelector,
      emptyBuilder: emptyBuilder,
      height: 230,
      itemCount: episodes.length,
      padding: EdgeInsets.zero,
      separatorBuilder: (context, index) => const SizedBox(width: 16),
      itemBuilder: (context, index) {
        final episode = episodes[index];
        final epNum = episode.episodeNumber;
        final watchCount = watchedEpisodesCount['$seasonNumber-$epNum'] ?? 0;
        final isWatched = watchCount > 0;
        final resumePercentage = seriesDomainService.calculateResumePercentage(
          seasonNumber: seasonNumber,
          episodeNumber: epNum,
          episodeProgress: episodeProgress,
        );

        return EpisodeCarouselCard(
          episode: episode,
          seasonNumber: seasonNumber,
          mediaId: mediaId,
          isWatched: isWatched,
          watchCount: watchCount,
          resumePercentage: resumePercentage,
          onEpisodeTap: onEpisodeTap,
          onMarkWatched: onMarkWatched,
          onTrackOptions: onTrackOptions,
          onFindMissingPreceding: onFindMissingPreceding,
          onShowMarkPrecedingModal: onShowMarkPrecedingModal,
          onShowComments: onShowComments != null
              ? () => onShowComments!(seasonNumber, epNum)
              : null,
          onViewHistory: onViewHistory != null
              ? () => onViewHistory!(seasonNumber, epNum)
              : null,
        );
      },
    );
  }
}
