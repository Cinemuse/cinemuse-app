import 'package:cinemuse_app/features/media/application/media_details_controller.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episode_card.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/tracking_modals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class EpisodeList extends ConsumerStatefulWidget {
  final List<dynamic> episodes;
  final int seasonNumber;
  final Map<String, dynamic> media;
  final Map<String, dynamic>? watchedData;
  final Map<String, int>? watchedEpisodesCount;
  final Map<String, WatchHistory>? episodeProgress;
  final Function(int season, int episode, String name)? onEpisodeTap;
  final int? initialScrollIndex;

  const EpisodeList({
    super.key,
    required this.episodes,
    required this.seasonNumber,
    required this.media,
    this.watchedData,
    this.watchedEpisodesCount,
    this.episodeProgress,
    this.onEpisodeTap,
    this.initialScrollIndex,
  });

  @override
  ConsumerState<EpisodeList> createState() => _EpisodeListState();
}

class _EpisodeListState extends ConsumerState<EpisodeList> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _tryScroll(widget.initialScrollIndex);
  }

  @override
  void didUpdateWidget(covariant EpisodeList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.seasonNumber != oldWidget.seasonNumber) {
      // Season changed, reset and try scroll
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      _tryScroll(widget.initialScrollIndex);
    }
  }

  void _tryScroll(int? index) {
    if (index != null && index > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final offset = index * 140.0; // Estimated item height
          _scrollController.jumpTo(offset.clamp(0.0, _scrollController.position.maxScrollExtent));
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(mediaDetailsControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;
    final tmdbId = int.parse(widget.media['id'].toString());

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: widget.episodes.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final episode = widget.episodes[index];
        final epNumber = episode['episode_number'];
        
        final watchCount = widget.watchedEpisodesCount?['${widget.seasonNumber}-$epNumber'] ?? 0;
        final bool isWatched = watchCount > 0;
        
        double? resumePercentage;
        final epKey = '${widget.seasonNumber}-$epNumber';
        if (widget.episodeProgress != null && widget.episodeProgress!.containsKey(epKey)) {
          final history = widget.episodeProgress![epKey]!;
          if (history.status == WatchStatus.watching && history.totalDuration != null && history.totalDuration! > 0) {
            resumePercentage = history.progressSeconds / history.totalDuration!;
          }
        }
        
        if (resumePercentage == null && widget.watchedData != null) {
          final lastSeason = widget.watchedData!['season'] as int?;
          final lastEpisode = widget.watchedData!['episode'] as int?;
          
          if (lastSeason == widget.seasonNumber && lastEpisode == epNumber) {
            final progress = widget.watchedData!['progress_seconds'] as int? ?? 0;
            final total = widget.watchedData!['total_duration'] as int? ?? 0;
            if (total > 0) {
              resumePercentage = progress / total;
            }
          }
        }

        return EpisodeCard(
          episode: episode,
          seasonNumber: widget.seasonNumber,
          media: widget.media,
          isWatched: isWatched,
          watchCount: watchCount,
          resumePercentage: resumePercentage,
          onEpisodeTap: widget.onEpisodeTap,
          onMarkWatched: (s, e, date) => controller.logEpisodeWatch(tmdbId: tmdbId, season: s, episode: e, loggedAt: date),
          onTrackOptions: (s, e) => _showTrackOptions(context, controller, tmdbId, s, e),
          onFindMissingPreceding: _findMissingPreceding,
          onShowMarkPrecedingModal: (s, e, m) => _showMarkPrecedingModal(context, controller, tmdbId, s, e, m),
        );
      },
    );
  }

  List<({int season, int episode})> _findMissingPreceding(int currentSeason, int currentEpisode) {
    final List<({int season, int episode})> missing = [];
    final seasons = widget.media['seasons'] as List? ?? [];
    
    for (final season in seasons) {
      final sNum = season['season_number'] as int? ?? 0;
      if (sNum == 0) continue; 
      if (sNum > currentSeason) break;
      
      final epCount = season['episode_count'] as int? ?? 0;
      final maxE = (sNum == currentSeason) ? currentEpisode - 1 : epCount;
      
      for (int e = 1; e <= maxE; e++) {
        final key = '$sNum-$e';
        if ((widget.watchedEpisodesCount?[key] ?? 0) == 0) {
          missing.add((season: sNum, episode: e));
        }
      }
    }
    return missing;
  }

  void _showMarkPrecedingModal(BuildContext context, MediaDetailsController controller, int tmdbId, int season, int episode, List<({int season, int episode})> missing) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.secondary,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.detailsMarkPreviousTitle, style: const TextStyle(color: Colors.white)),
        content: Text(
          l10n.detailsMarkPreviousDesc(episode.toString(), missing.length.toString()),
          style: const TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              controller.logEpisodeWatch(tmdbId: tmdbId, season: season, episode: episode);
            },
            child: Text(l10n.detailsOnlyThisOne, style: const TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final allToMark = [...missing, (season: season, episode: episode)];
              controller.logMultipleEpisodes(tmdbId: tmdbId, episodes: allToMark);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(l10n.detailsMarkAll),
          ),
        ],
      ),
    );
  }

  void _showTrackOptions(BuildContext context, MediaDetailsController controller, int tmdbId, int season, int episode) {
    showDialog(
      context: context,
      builder: (context) => TrackOptionsModal(
        season: season,
        episode: episode,
        onRewatch: (date) => controller.logEpisodeWatch(tmdbId: tmdbId, season: season, episode: episode, loggedAt: date),
        onRemoveOne: () => controller.deleteLatestEpisodeLog(tmdbId: tmdbId, season: season, episode: episode),
        onRemoveAll: () => controller.deleteAllEpisodeLogs(tmdbId: tmdbId, season: season, episode: episode),
      ),
    );
  }
}
