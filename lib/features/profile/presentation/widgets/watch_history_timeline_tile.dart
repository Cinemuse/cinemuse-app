import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/constants/tmdb_image_helper.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/add_to_list_sheet.dart';
import 'package:cinemuse_app/shared/widgets/menu/app_menu.dart';
import 'package:cinemuse_app/shared/widgets/premium_hover_text.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

/// A card representation of a single watched title in the chronological timeline.
class WatchHistoryTimelineTile extends ConsumerStatefulWidget {
  final WatchHistory item;
  final String appLanguage;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  const WatchHistoryTimelineTile({
    super.key,
    required this.item,
    required this.appLanguage,
    required this.onTap,
    required this.onPlay,
  });

  @override
  ConsumerState<WatchHistoryTimelineTile> createState() =>
      _WatchHistoryTimelineTileState();
}

class _WatchHistoryTimelineTileState
    extends ConsumerState<WatchHistoryTimelineTile> {
  final GlobalKey _menuKey = GlobalKey();
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.sizeOf(context).width < 650;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: _isHovered ? 0.95 : 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered
                ? AppTheme.accent.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.12),
                    blurRadius: 12,
                  ),
                ]
              : AppTheme.shadowCard,
        ),
        padding: const EdgeInsets.all(12),
        child: isMobile
            ? _buildMobileLayout(context, l10n)
            : _buildDesktopLayout(context, l10n),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildPoster(context),
        const SizedBox(width: 16),
        Expanded(child: _buildDetails(context, l10n)),
        const SizedBox(width: 16),
        _buildActionBlock(context, l10n),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPoster(context),
            const SizedBox(width: 12),
            Expanded(child: _buildDetails(context, l10n)),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(color: Colors.white10, height: 1),
        const SizedBox(height: 8),
        _buildActionBlock(context, l10n, isMobile: true),
      ],
    );
  }

  Widget _buildPoster(BuildContext context) {
    final posterUrl = TmdbImageHelper.posterUrl(
      context,
      widget.item.media?.posterPath,
    );

    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 62,
          height: 90,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.black45,
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (posterUrl != null)
                CachedNetworkImage(
                  imageUrl: posterUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: AppTheme.surface,
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.white24),
                  ),
                )
              else
                const Center(
                  child: Icon(
                    Icons.movie_rounded,
                    color: Colors.white24,
                    size: 28,
                  ),
                ),
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white24, width: 0.5),
                  ),
                  child: Text(
                    widget.item.mediaType == MediaKind.tv ? 'TV' : 'FILM',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetails(BuildContext context, AppLocalizations l10n) {
    final media = widget.item.media;
    final title =
        media?.getLocalizedTitle(widget.appLanguage) ?? l10n.commonUnknown;
    final isTv = widget.item.mediaType == MediaKind.tv;
    final season = widget.item.season;
    final episode = widget.item.episode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: widget.onTap,
                child: PremiumHoverText(
                  text: title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildStatusBadge(l10n),
          ],
        ),
        const SizedBox(height: 4),
        if (isTv &&
            season != null &&
            episode != null &&
            season > 0 &&
            episode > 0)
          Text(
            l10n.watchHistorySeasonEpisode(season, episode),
            style: const TextStyle(
              color: AppTheme.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          )
        else
          Row(
            children: [
              if (media?.releaseDate != null)
                Text(
                  '${media!.releaseDate!.year}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              if (media?.voteAverage != null && media!.voteAverage! > 0) ...[
                const SizedBox(width: 8),
                const Icon(Icons.star, size: 12, color: AppTheme.star),
                const SizedBox(width: 3),
                Text(
                  media.voteAverage!.toStringAsFixed(1),
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        if (_hasProgress) ...[const SizedBox(height: 8), _buildProgressBar()],
      ],
    );
  }

  bool get _hasProgress {
    final total = widget.item.totalDuration ?? 0;
    final progress = widget.item.progressSeconds;
    return progress > 0 &&
        total > 0 &&
        widget.item.status != WatchStatus.completed;
  }

  Widget _buildProgressBar() {
    final total = widget.item.totalDuration ?? 1;
    final progress = widget.item.progressSeconds;
    final fraction = (progress / total).clamp(0.0, 1.0);
    final percentage = (fraction * 100).toInt();

    final watchedMinutes = (progress / 60).round();
    final totalMinutes = (total / 60).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${watchedMinutes}m / ${totalMinutes}m',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
            Text(
              '$percentage%',
              style: const TextStyle(
                color: AppTheme.accent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: fraction,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(AppLocalizations l10n) {
    final status = widget.item.status ?? WatchStatus.watching;
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case WatchStatus.completed:
        color = const Color(0xFF10B981);
        label = l10n.watchHistoryStatusCompleted;
        icon = Icons.check_circle_rounded;
        break;
      case WatchStatus.dropped:
        color = const Color(0xFFF43F5E);
        label = l10n.watchHistoryStatusDropped;
        icon = Icons.cancel_rounded;
        break;
      case WatchStatus.watching:
        color = const Color(0xFFF59E0B);
        label = l10n.watchHistoryStatusWatching;
        icon = Icons.play_circle_outline_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBlock(
    BuildContext context,
    AppLocalizations l10n, {
    bool isMobile = false,
  }) {
    final timestamp = _formatTimestamp(widget.item.lastWatchedAt, l10n);
    final isCompleted = widget.item.status == WatchStatus.completed;

    return Row(
      mainAxisAlignment: isMobile
          ? MainAxisAlignment.spaceBetween
          : MainAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.access_time_rounded,
              size: 12,
              color: AppTheme.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              timestamp,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
        if (isMobile) const Spacer(),
        const SizedBox(width: 12),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: widget.onPlay,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isCompleted
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppTheme.accent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isCompleted ? null : AppTheme.shadowAccentGlow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCompleted
                        ? Icons.replay_rounded
                        : Icons.play_arrow_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isCompleted
                        ? l10n.watchHistoryWatchAgain
                        : l10n.watchHistoryResume,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          key: _menuKey,
          icon: const Icon(Icons.more_vert, size: 18, color: Colors.white60),
          onPressed: () => _showContextMenu(context),
          tooltip: l10n.homeMoreInfo,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  void _showContextMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final media = widget.item.media;
    final title =
        media?.getLocalizedTitle(widget.appLanguage) ??
        widget.item.tmdbId.toString();

    final isWatchlisted =
        ref
            .read(userListsProvider)
            .valueOrNull
            ?.where((l) => l.type == ListType.watchlist)
            .firstOrNull
            ?.items
            .any(
              (i) =>
                  i.tmdbId == widget.item.tmdbId &&
                  i.mediaType == widget.item.mediaType,
            ) ??
        false;

    final options = [
      AppMenuOption(
        icon: Icons.play_arrow_outlined,
        label: l10n.menuPlay,
        onTap: widget.onPlay,
      ),
      AppMenuOption(
        icon: Icons.info_outline,
        label: l10n.homeMoreInfo,
        onTap: widget.onTap,
      ),
      AppMenuOption(
        icon: isWatchlisted
            ? Icons.bookmark_remove
            : Icons.bookmark_add_outlined,
        label: isWatchlisted
            ? l10n.menuRemoveFromWatchlist
            : l10n.menuAddToWatchlist,
        onTap: () {
          if (media != null) {
            ref.read(userListsProvider.notifier).toggleWatchlist(media);
          }
        },
      ),
      if (media != null)
        AppMenuOption(
          icon: Icons.playlist_add,
          label: l10n.detailsAddToList,
          onTap: () => AddToListSheet.show(context, media),
        ),
      AppMenuOption(
        icon: Icons.delete_outline_rounded,
        label: l10n.menuRemoveFromContinueWatching,
        onTap: () {
          final user = ref.read(authProvider).value;
          if (user != null) {
            ref
                .read(watchHistoryRepositoryProvider)
                .clearProgress(
                  userId: user.id,
                  tmdbId: widget.item.tmdbId,
                  mediaType: widget.item.mediaType.name,
                );
          }
        },
      ),
    ];

    AppMenu.show(
      context: context,
      options: options,
      title: title,
      anchorContext: _menuKey.currentContext,
    );
  }

  String _formatTimestamp(DateTime dateTime, AppLocalizations l10n) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return l10n.watchHistoryMinutesAgo(difference.inMinutes.clamp(1, 60));
    }
    if (difference.inHours < 24 && dateTime.day == now.day) {
      return l10n.watchHistoryHoursAgo(difference.inHours);
    }
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
