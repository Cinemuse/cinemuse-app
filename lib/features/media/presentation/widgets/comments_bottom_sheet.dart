import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/application/comments_provider.dart';
import 'package:cinemuse_app/features/media/domain/comment.dart';
import 'package:cinemuse_app/features/media/domain/comments_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/comment_tile.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_bottom_sheet.dart';

class CommentsBottomSheet extends ConsumerStatefulWidget {
  final CommentsRequest request;

  const CommentsBottomSheet({super.key, required this.request});

  @override
  ConsumerState<CommentsBottomSheet> createState() =>
      _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends ConsumerState<CommentsBottomSheet> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      final state = ref.read(commentsProvider(widget.request));
      if (!state.isLoading && !state.isLoadingMore && state.hasMore) {
        ref.read(commentsProvider(widget.request).notifier).loadNextPage();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(commentsProvider(widget.request));

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final bool isMobile = width < 600;

        return AppBottomSheet(
          backgroundColor: AppTheme.primary,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8), // Extra space after handle
              if (isMobile) ...[
                Text(l10n.detailsTvTimeComments, style: DesktopTypography.sectionHeader),
                if (!state.isLoading && state.hasAnyComments) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSourceFilterMenu(
                          context,
                          state,
                          isMobile,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _buildSortMenu(context, state, isMobile)),
                    ],
                  ),
                ],
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.detailsTvTimeComments,
                      style: DesktopTypography.sectionHeader,
                    ),
                    if (!state.isLoading && state.hasAnyComments)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSourceFilterMenu(context, state, isMobile),
                          const SizedBox(width: 12),
                          _buildSortMenu(context, state, isMobile),
                        ],
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Expanded(child: _buildContent(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    CommentsState state,
  ) {
    final l10n = AppLocalizations.of(context)!;

    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      );
    }
    if (state.error != null) {
      return Center(
        child: Text(
          '${l10n.tvTimeCommentsError} (${state.error})',
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    }
    if (state.comments.isEmpty) {
      return Center(
        child: Text(
          l10n.tvTimeNoComments,
          style: const TextStyle(color: AppTheme.textMuted),
        ),
      );
    }

    final comments = state.comments;
    final bool showLoader = state.isLoadingMore;

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: comments.length + (showLoader ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index >= comments.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            ),
          );
        }
        final comment = comments[index];
        return CommentTile(
          key: ValueKey(comment.id),
          comment: comment,
        );
      },
    );
  }

  Widget _buildSourceFilterMenu(
    BuildContext context,
    CommentsState state,
    bool isMobile,
  ) {
    final l10n = AppLocalizations.of(context)!;
    String label;
    switch (state.sourceFilter) {
      case CommentSourceFilter.all:
        label = l10n.commentsFilterAllSources;
        break;
      case CommentSourceFilter.serializd:
        label = l10n.commentsSourceSerializd;
        break;
      case CommentSourceFilter.letterboxd:
        label = l10n.commentsSourceLetterboxd;
        break;
      case CommentSourceFilter.imdb:
        label = l10n.commentsSourceImdb;
        break;
    }

    return PopupMenuButton<CommentSourceFilter>(
      color: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (val) {
        ref
            .read(commentsProvider(widget.request).notifier)
            .setSourceFilter(val);
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      },
      itemBuilder: (context) {
        final isTv = widget.request is EpisodeCommentsRequest ||
            (widget.request is MediaReviewsRequest &&
                (widget.request as MediaReviewsRequest).mediaType == MediaKind.tv);
        final hasSerializd = state.availableSources.contains(CommentSource.serializd);
        final hasLetterboxd = state.availableSources.contains(CommentSource.letterboxd);

        return [
          _buildPopupMenuItem(
            CommentSourceFilter.all,
            l10n.commentsFilterAllSources,
            state.sourceFilter,
          ),
          if (hasSerializd || isTv)
            _buildPopupMenuItem(
              CommentSourceFilter.serializd,
              l10n.commentsSourceSerializd,
              state.sourceFilter,
            ),
          if (hasLetterboxd || !isTv)
            _buildPopupMenuItem(
              CommentSourceFilter.letterboxd,
              l10n.commentsSourceLetterboxd,
              state.sourceFilter,
            ),
          _buildPopupMenuItem(
            CommentSourceFilter.imdb,
            l10n.commentsSourceImdb,
            state.sourceFilter,
          ),
        ];
      },
      child: _buildFilterChip(label, Icons.layers_outlined, isMobile),
    );
  }

  Widget _buildSortMenu(
    BuildContext context,
    CommentsState state,
    bool isMobile,
  ) {
    final l10n = AppLocalizations.of(context)!;
    String label;
    switch (state.sortType) {
      case CommentSortType.mostLiked:
        label = l10n.commentsSortMostLiked;
        break;
      case CommentSortType.recent:
        label = l10n.commentsSortRecent;
        break;
      case CommentSortType.highestRating:
        label = l10n.commentsSortRating;
        break;
    }

    return PopupMenuButton<CommentSortType>(
      color: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (val) {
        ref
            .read(commentsProvider(widget.request).notifier)
            .setSortType(val);
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      },
      itemBuilder: (context) => [
        _buildPopupMenuItem(
          CommentSortType.mostLiked,
          l10n.commentsSortMostLiked,
          state.sortType,
        ),
        _buildPopupMenuItem(
          CommentSortType.recent,
          l10n.commentsSortRecent,
          state.sortType,
        ),
        _buildPopupMenuItem(
          CommentSortType.highestRating,
          l10n.commentsSortRating,
          state.sortType,
        ),
      ],
      child: _buildFilterChip(label, Icons.sort, isMobile),
    );
  }

  Widget _buildFilterChip(String label, IconData icon, bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.textWhite.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
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
    );
  }

  PopupMenuItem<T> _buildPopupMenuItem<T>(
    T value,
    String label,
    T currentValue,
  ) {
    final isSelected = value == currentValue;
    return PopupMenuItem<T>(
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
}

void showCommentsBottomSheet(BuildContext context, CommentsRequest request) {
  final screenWidth = MediaQuery.of(context).size.width;
  AppBottomSheet.show(
    context: context,
    heightFactor: 0.85,
    constraints: BoxConstraints(
      maxWidth: screenWidth > 680 ? 680 : screenWidth,
    ),
    child: CommentsBottomSheet(request: request),
  );
}
