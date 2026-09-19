import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/cards/episode_thumbnail_card.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/carousels/generic_carousel_row.dart';
import 'package:flutter/material.dart';

/// A horizontal carousel row of episodes for a TV series season.
class EpisodeCarouselRow extends StatelessWidget {
  final List<dynamic> episodes;
  final int seasonNumber;
  final String mediaId;
  final Map<String, int> watchedEpisodesCount;
  final Map<String, WatchHistory>? episodeProgress;
  final Map<String, dynamic>? watchedData;
  final Widget? seasonSelector;
  final Function(int season, int episode, String name)? onEpisodeTap;
  final Function(int season, int episode, DateTime? date)? onMarkWatched;
  final Function(int season, int episode)? onTrackOptions;
  final List<({int season, int episode})> Function(int season, int episode)?
  onFindMissingPreceding;
  final Function(int season, int episode, List<({int season, int episode})> missing)?
  onShowMarkPrecedingModal;
  final void Function(int season, int episode)? onShowComments;

  const EpisodeCarouselRow({
    super.key,
    required this.episodes,
    required this.seasonNumber,
    required this.mediaId,
    this.watchedEpisodesCount = const {},
    this.episodeProgress,
    this.watchedData,
    this.seasonSelector,
    this.onEpisodeTap,
    this.onMarkWatched,
    this.onTrackOptions,
    this.onFindMissingPreceding,
    this.onShowMarkPrecedingModal,
    this.onShowComments,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (episodes.isEmpty) {
      return const SizedBox.shrink();
    }

    return GenericCarouselRow(
      title: l10n.detailsEpisodes,
      icon: Icons.tv,
      theme: CarouselTheme.bentoBox,
      headerAction: seasonSelector,
      height: 230,
      itemCount: episodes.length,
      padding: EdgeInsets.zero,
      separatorBuilder: (context, index) => const SizedBox(width: 16),
      itemBuilder: (context, index) {
        final episode = episodes[index];
        final epNum = episode['episode_number'] as int? ?? (index + 1);
        final watchCount = watchedEpisodesCount['$seasonNumber-$epNum'] ?? 0;
        final isWatched = watchCount > 0;
        final resumePercentage = _calculateResumePercentage(epNum);

        return EpisodeThumbnailCard(
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
        );
      },
    );
  }

  double? _calculateResumePercentage(int epNumber) {
    final epKey = '$seasonNumber-$epNumber';
    if (episodeProgress != null && episodeProgress!.containsKey(epKey)) {
      final history = episodeProgress![epKey]!;
      if (history.status == WatchStatus.watching &&
          history.totalDuration != null &&
          history.totalDuration! > 0) {
        return history.progressSeconds / history.totalDuration!;
      }
    }

    if (watchedData != null) {
      final lastSeason = watchedData!['season'] as int?;
      final lastEpisode = watchedData!['episode'] as int?;
      if (lastSeason == seasonNumber && lastEpisode == epNumber) {
        final progress = watchedData!['progress_seconds'] as int? ?? 0;
        final total = watchedData!['total_duration'] as int? ?? 0;
        if (total > 0) {
          return progress / total;
        }
      }
    }

    return null;
  }
}
