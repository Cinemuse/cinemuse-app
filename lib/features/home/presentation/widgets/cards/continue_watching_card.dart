import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cinemuse_app/core/services/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/shared/widgets/backdrop_card.dart';
import 'package:cinemuse_app/shared/widgets/skeleton_box.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';

class ContinueWatchingCard extends ConsumerStatefulWidget {
  final WatchHistory historyItem;
  final List<UserListItem> watchlistItems;
  final VoidCallback onRemove;

  const ContinueWatchingCard({
    super.key,
    required this.historyItem,
    required this.watchlistItems,
    required this.onRemove,
  });

  @override
  ConsumerState<ContinueWatchingCard> createState() => _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends ConsumerState<ContinueWatchingCard> {
  @override
  Widget build(BuildContext context) {
    final localMedia = widget.historyItem.media;
    
    if (localMedia != null) {
      return _buildCard(context, ref, localMedia);
    }

    final mediaAsync = ref.watch(mediaItemProvider((
      id: widget.historyItem.tmdbId, 
      type: widget.historyItem.mediaType
    )));

    return mediaAsync.when(
      data: (media) => _buildCard(context, ref, media),
      loading: () => _buildSkeleton(),
      error: (_, __) => _buildCard(context, ref, null),
    );
  }

  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(width: 280, height: 280 * (9 / 16)),
        const SizedBox(height: 10),
        const SkeletonBox(width: 150, height: 16),
      ],
    );
  }

  Widget _buildCard(BuildContext context, WidgetRef ref, MediaItem? media) {
    final isWatchlisted = widget.watchlistItems.any((i) => 
      i.tmdbId == widget.historyItem.tmdbId && i.mediaType == widget.historyItem.mediaType
    );
    final appLanguage = ref.watch(settingsProvider).appLanguage;
    final title = media?.getLocalizedTitle(appLanguage) ?? '...';
    
    final percentage = (widget.historyItem.totalDuration != null && widget.historyItem.totalDuration! > 0)
        ? (widget.historyItem.progressSeconds / widget.historyItem.totalDuration!)
        : 0.0;

    final resolver = ref.read(unifiedStreamResolverProvider);
    final hasCache = resolver.hasCachedStream(
      widget.historyItem.tmdbId.toString(),
      widget.historyItem.mediaType == MediaKind.tv ? 'tv' : 'movie',
      season: widget.historyItem.season,
      episode: widget.historyItem.episode,
    );

    return BackdropCard(
      key: ValueKey(widget.historyItem.tmdbId),
      title: title,
      backdropPath: media?.backdropPath,
      posterPath: media?.posterPath,
      progress: percentage,
      infoText: widget.historyItem.mediaType == MediaKind.tv 
                ? "S${widget.historyItem.season} E${widget.historyItem.episode}" 
                : "Movie",
      isWatchlisted: isWatchlisted,
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(
            queryId: widget.historyItem.tmdbId.toString(),
            type: widget.historyItem.mediaType == MediaKind.tv ? 'tv' : 'movie',
            season: widget.historyItem.season,
            episode: widget.historyItem.episode,
            startPosition: widget.historyItem.progressSeconds,
          ),
        ));
      },
      onRestart: () {
        Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(
            queryId: widget.historyItem.tmdbId.toString(),
            type: widget.historyItem.mediaType == MediaKind.tv ? 'tv' : 'movie',
            season: widget.historyItem.season,
            episode: widget.historyItem.episode,
            startPosition: 0,
          ),
        ));
      },
      onDetails: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MediaDetailsScreen(
            mediaId: widget.historyItem.tmdbId.toString(), 
            mediaType: widget.historyItem.mediaType == MediaKind.tv ? 'tv' : 'movie',
          ),
        ));
      },
      onWatchlistToggle: () {
        if (media != null) {
          ref.read(userListsProvider.notifier).toggleWatchlist(media);
        }
      },
      onRemove: widget.onRemove,
      onClearCache: hasCache ? () {
        resolver.clearCachedStream(
          widget.historyItem.tmdbId.toString(),
          widget.historyItem.mediaType == MediaKind.tv ? 'tv' : 'movie',
          season: widget.historyItem.season,
          episode: widget.historyItem.episode,
        );
        setState(() {});
      } : null,
    );
  }
}
