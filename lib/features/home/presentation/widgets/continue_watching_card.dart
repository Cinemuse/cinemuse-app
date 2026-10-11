import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver_provider.dart';
import 'package:cinemuse_app/shared/widgets/backdrop_card.dart';
import 'package:cinemuse_app/shared/widgets/skeleton_box.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/add_to_list_sheet.dart';

class ContinueWatchingCard extends ConsumerStatefulWidget {
  final WatchHistory historyItem;
  final VoidCallback onCancelRewatch;
  final VoidCallback? onDrop;
  final VoidCallback? onClearProgress;
  final double? width;

  const ContinueWatchingCard({
    super.key,
    required this.historyItem,
    required this.onCancelRewatch,
    this.onDrop,
    this.onClearProgress,
    this.width,
  });

  @override
  ConsumerState<ContinueWatchingCard> createState() =>
      _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends ConsumerState<ContinueWatchingCard> {
  @override
  Widget build(BuildContext context) {
    final localMedia = widget.historyItem.media;
    final appLanguage = ref.watch(
      settingsProvider.select((s) => s.appLanguage),
    );

    if (localMedia != null && localMedia.hasCompleteTitle(appLanguage)) {
      return _buildCard(context, ref, localMedia, appLanguage);
    }

    final mediaAsync = ref.watch(
      mediaItemProvider((
        id: widget.historyItem.tmdbId,
        type: widget.historyItem.mediaType,
      )),
    );

    return mediaAsync.when(
      // Offline or TMDB failed (null): still a usable card from the local
      // data, titled "Unknown", so it can be resumed or removed.
      data: (media) =>
          _buildCard(context, ref, media ?? localMedia, appLanguage),
      loading: _buildSkeleton,
      error: (_, __) => _buildCard(context, ref, localMedia, appLanguage),
    );
  }

  Widget _buildSkeleton() {
    final w = widget.width ?? 280.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(width: w, height: w * (9 / 16)),
        const SizedBox(height: 10),
        SkeletonBox(width: w * 0.55, height: 16),
      ],
    );
  }

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    MediaItem? media,
    String appLanguage,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final isRewatching =
        ref.watch(isRewatchingProvider(widget.historyItem)).valueOrNull ??
        false;

    final title = media != null && media.hasCompleteTitle(appLanguage)
        ? media.getLocalizedTitle(appLanguage)!
        : l10n.commonUnknown;
    final item = widget.historyItem;
    final type = item.mediaType.name;

    final percentage =
        (widget.historyItem.totalDuration != null &&
            widget.historyItem.totalDuration! > 0)
        ? (widget.historyItem.progressSeconds /
              widget.historyItem.totalDuration!)
        : 0.0;

    final resolver = ref.watch(unifiedStreamResolverProvider);
    final hasCache = resolver.hasCachedStream(
      widget.historyItem.tmdbId.toString(),
      type,
      season: widget.historyItem.season,
      episode: widget.historyItem.episode,
    );

    return BackdropCard(
      key: ValueKey('$type-${item.tmdbId}'),
      title: title,
      width: widget.width,
      backdropPath: media?.backdropPath,
      posterPath: media?.posterPath,
      progress: percentage,
      infoText: widget.historyItem.mediaType == MediaKind.tv
          ? "S${widget.historyItem.season} E${widget.historyItem.episode}"
          : l10n.personMovie,
      isWatchlistedCallback: () => ref
          .read(userListsProvider.notifier)
          .isInWatchlist(
            widget.historyItem.tmdbId,
            widget.historyItem.mediaType,
          ),
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(
              queryId: widget.historyItem.tmdbId.toString(),
              type: type,
              season: widget.historyItem.season,
              episode: widget.historyItem.episode,
              startPosition: widget.historyItem.progressSeconds,
            ),
          ),
        );
      },
      onRestart: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(
              queryId: widget.historyItem.tmdbId.toString(),
              type: type,
              season: widget.historyItem.season,
              episode: widget.historyItem.episode,
              startPosition: 0,
            ),
          ),
        );
      },
      onDetails: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MediaDetailsScreen(
              mediaId: widget.historyItem.tmdbId.toString(),
              mediaType: type,
            ),
          ),
        );
      },
      onWatchlistToggle: () {
        if (media != null) {
          ref.read(userListsProvider.notifier).toggleWatchlist(media);
        }
      },
      onAddToList: media != null
          ? () {
              AddToListSheet.show(context, media);
            }
          : null,
      onDrop: isRewatching ? null : widget.onDrop,
      onCancelRewatch: isRewatching ? widget.onCancelRewatch : null,
      onClearProgress: widget.onClearProgress,
      onClearCache: hasCache
          ? () {
              resolver.clearCachedStream(
                widget.historyItem.tmdbId.toString(),
                type,
                season: widget.historyItem.season,
                episode: widget.historyItem.episode,
              );
              setState(() {});
            }
          : null,
    );
  }
}
