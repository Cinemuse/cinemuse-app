import 'package:cinemuse_app/features/media/application/series_domain_service.dart';
import 'package:cinemuse_app/features/media/domain/episode_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/episode_list_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Vertical list of episodes for mobile TV series presentation.
class EpisodeList extends ConsumerWidget {
  final List<EpisodeItem> episodes;
  final int seasonNumber;
  final String mediaId;
  final Map<String, int>? watchedEpisodesCount;
  final Map<String, WatchHistory>? episodeProgress;
  final void Function(int season, int episode, String name, {bool restart})? onEpisodeTap;
  final void Function(int season, int episode)? onShowComments;
  final Function(int season, int episode, DateTime? date)? onMarkWatched;
  final Function(int season, int episode)? onTrackOptions;
  final List<({int season, int episode})> Function(int season, int episode)? onFindMissingPreceding;
  final Function(int season, int episode, List<({int season, int episode})> missing)? onShowMarkPrecedingModal;
  final Function(int season, int episode)? onViewHistory;

  const EpisodeList({
    super.key,
    required this.episodes,
    required this.seasonNumber,
    required this.mediaId,
    this.watchedEpisodesCount,
    this.episodeProgress,
    this.onEpisodeTap,
    this.onShowComments,
    this.onMarkWatched,
    this.onTrackOptions,
    this.onFindMissingPreceding,
    this.onShowMarkPrecedingModal,
    this.onViewHistory,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seriesDomainService = ref.watch(seriesDomainServiceProvider);

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: episodes.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final episode = episodes[index];
        final epNumber = episode.episodeNumber;

        final watchCount =
            watchedEpisodesCount?['$seasonNumber-$epNumber'] ?? 0;
        final bool isWatched = watchCount > 0;

        final resumePercentage = seriesDomainService.calculateResumePercentage(
          seasonNumber: seasonNumber,
          episodeNumber: epNumber,
          episodeProgress: episodeProgress,
        );

        return EpisodeListCard(
          episode: episode,
          seasonNumber: seasonNumber,
          mediaId: mediaId,
          isWatched: isWatched,
          watchCount: watchCount,
          resumePercentage: resumePercentage,
          onEpisodeTap: onEpisodeTap,
          onShowComments: onShowComments != null
              ? () => onShowComments!(seasonNumber, epNumber)
              : null,
          onMarkWatched: onMarkWatched,
          onTrackOptions: (s, e) => onTrackOptions?.call(s, e),
          onFindMissingPreceding: (s, e) =>
              onFindMissingPreceding?.call(s, e) ?? [],
          onShowMarkPrecedingModal: (s, e, m) =>
              onShowMarkPrecedingModal?.call(s, e, m),
          onViewHistory: onViewHistory != null
              ? () => onViewHistory!(seasonNumber, epNumber)
              : null,
        );
      },
    );
  }
}
