import 'dart:async';

import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/application/comments_provider.dart';
import 'package:cinemuse_app/features/media/domain/comment.dart';
import 'package:cinemuse_app/features/media/domain/comments_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';
import 'package:cinemuse_app/shared/widgets/menu/menu_focus_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The reviews sheet's menu of review sites.
class CommentSourceFilterMenu extends ConsumerWidget {
  final CommentsRequest request;
  final bool isMobile;
  final String seriesSite;

  /// A choice was made: the list goes back to its top.
  final VoidCallback onChanged;

  const CommentSourceFilterMenu({
    super.key,
    required this.request,
    required this.isMobile,
    required this.seriesSite,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(commentsProvider(request));
    final label = switch (state.sourceFilter) {
      CommentSourceFilter.all => l10n.commentsFilterAllSources,
      CommentSourceFilter.seriesReviews => seriesSite,
      CommentSourceFilter.letterboxd => l10n.commentsSourceLetterboxd,
      CommentSourceFilter.imdb => l10n.commentsSourceImdb,
    };

    // The menu button is an InkWell with no ring of its own.
    return FocusRingFollower(
      borderRadius: AppTheme.radius12,
      child: PopupMenuButton<CommentSourceFilter>(
        color: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        position: PopupMenuPosition.under,
        shape: const RoundedRectangleBorder(borderRadius: AppTheme.radius12),
        onSelected: (val) {
          // Not awaited: it may load a few pages to fill the filtered list.
          unawaited(
            ref.read(commentsProvider(request).notifier).setSourceFilter(val),
          );
          onChanged();
        },
        itemBuilder: (context) {
          final isTv = switch (request) {
            EpisodeCommentsRequest() => true,
            final MediaReviewsRequest request =>
              request.mediaType == MediaKind.tv,
            _ => false,
          };
          final hasSeriesReviews = state.availableSources.contains(
            CommentSource.seriesReviews,
          );
          final hasLetterboxd = state.availableSources.contains(
            CommentSource.letterboxd,
          );

          return [
            _menuItem(
              CommentSourceFilter.all,
              l10n.commentsFilterAllSources,
              state.sourceFilter,
            ),
            if (hasSeriesReviews || isTv)
              _menuItem(
                CommentSourceFilter.seriesReviews,
                seriesSite,
                state.sourceFilter,
              ),
            if (hasLetterboxd || !isTv)
              _menuItem(
                CommentSourceFilter.letterboxd,
                l10n.commentsSourceLetterboxd,
                state.sourceFilter,
              ),
            _menuItem(
              CommentSourceFilter.imdb,
              l10n.commentsSourceImdb,
              state.sourceFilter,
            ),
          ];
        },
        child: _FilterChip(
          label: label,
          icon: Icons.layers_outlined,
          isMobile: isMobile,
        ),
      ),
    );
  }
}

/// The reviews sheet's menu of orders.
class CommentSortMenu extends ConsumerWidget {
  final CommentsRequest request;
  final bool isMobile;

  /// A choice was made: the list goes back to its top.
  final VoidCallback onChanged;

  const CommentSortMenu({
    super.key,
    required this.request,
    required this.isMobile,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final sortType = ref.watch(
      commentsProvider(request).select((state) => state.sortType),
    );
    final label = switch (sortType) {
      CommentSortType.mostLiked => l10n.commentsSortMostLiked,
      CommentSortType.recent => l10n.commentsSortRecent,
      CommentSortType.highestRating => l10n.commentsSortRating,
    };

    // The menu button is an InkWell with no ring of its own.
    return FocusRingFollower(
      borderRadius: AppTheme.radius12,
      child: PopupMenuButton<CommentSortType>(
        color: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        position: PopupMenuPosition.under,
        shape: const RoundedRectangleBorder(borderRadius: AppTheme.radius12),
        onSelected: (val) {
          ref.read(commentsProvider(request).notifier).setSortType(val);
          onChanged();
        },
        itemBuilder: (context) => [
          _menuItem(
            CommentSortType.mostLiked,
            l10n.commentsSortMostLiked,
            sortType,
          ),
          _menuItem(CommentSortType.recent, l10n.commentsSortRecent, sortType),
          _menuItem(
            CommentSortType.highestRating,
            l10n.commentsSortRating,
            sortType,
          ),
        ],
        child: _FilterChip(label: label, icon: Icons.sort, isMobile: isMobile),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isMobile;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    // The menu button's own InkWell has no cursor option (REV-246).
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.textWhite.withValues(alpha: 0.05),
          borderRadius: AppTheme.radius12,
          border: Border.all(color: AppTheme.textWhite.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: AppTheme.textWhite.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: DesktopTypography.bodySecondary.copyWith(
                        fontSize: 14,
                        color: AppTheme.textWhite,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isMobile) const SizedBox(width: 4),
            Icon(
              Icons.unfold_more_rounded,
              size: 18,
              color: AppTheme.textWhite.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

PopupMenuItem<T> _menuItem<T>(T value, String label, T currentValue) {
  final isSelected = value == currentValue;
  return AppPopupMenuItem<T>(
    value: value,
    child: Text(
      label,
      style: DesktopTypography.bodySecondary.copyWith(
        color: isSelected ? AppTheme.accent : AppTheme.textWhite,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      ),
    ),
  );
}
