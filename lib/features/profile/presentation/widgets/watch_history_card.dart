import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'package:cinemuse_app/features/profile/application/title_marks_provider.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/title_list_actions.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Space between the watch history cards.
const watchHistoryCardSpacing = 10.0;

/// Width / height of a watch history card.
const watchHistoryCardAspectRatio = 0.54;

/// How many cards fit in a row of [width]: 3 on a phone, else ~140 px each
/// (3 to 8). The grid and the timeline use the same (REV-110).
int watchHistoryColumnCount(double width) {
  if (width < Breakpoints.compact) return 3;
  return ((width + watchHistoryCardSpacing) / (140 + watchHistoryCardSpacing))
      .floor()
      .clamp(3, 8);
}

/// One watch history title: opens its page, plays it, shows progress.
class WatchHistoryCard extends ConsumerWidget {
  final WatchHistory item;

  /// The episodes on the card (timeline only).
  final String? infoText;
  final int? stackCount;

  /// The history or the Ratings view: each leaves out the mark it says.
  final MarksPlace marksPlace;

  const WatchHistoryCard({
    super.key,
    required this.item,
    this.infoText,
    this.stackCount,
    this.marksPlace = MarksPlace.history,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final language = ref.watch(settingsProvider.select((s) => s.appLanguage));
    final media = item.media;
    final total = item.totalDuration;
    final progress =
        (total != null &&
            total > 0 &&
            item.status != WatchStatus.completed &&
            item.progressSeconds > 0)
        ? item.progressSeconds / total
        : null;

    return MediaCard(
      title: media?.getLocalizedTitle(language) ?? l10n.commonUnknown,
      posterPath: media?.posterPath,
      releaseDate: media?.releaseDate?.year.toString(),
      rating: media?.voteAverage,
      listActions: media == null ? null : TitleListActions(context, ref, media),
      marks: ref.watch(
        titleMarksProvider((
          tmdbId: item.tmdbId,
          mediaType: item.mediaType,
          place: marksPlace,
        )),
      ),
      progress: progress,
      infoText: infoText,
      stackCount: stackCount,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MediaDetailsScreen(
            mediaId: item.tmdbId.toString(),
            mediaType: item.mediaType.name,
          ),
        ),
      ),
      onPlay: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(
            queryId: item.tmdbId.toString(),
            type: item.mediaType.name,
            season: item.season,
            episode: item.episode,
          ),
        ),
      ),
    );
  }
}
