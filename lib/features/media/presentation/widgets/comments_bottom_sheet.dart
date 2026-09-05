import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/application/comments_provider.dart';
import 'package:cinemuse_app/features/media/domain/comment.dart';
import 'package:cinemuse_app/features/media/domain/comments_repository.dart';
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
  int _displayCount = 20;
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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      final state = ref.read(commentsProvider(widget.request));
      if (!state.isLoading && !state.isLoadingMore) {
        if (_displayCount < state.comments.length) {
          setState(() {
            _displayCount += 20;
          });
        } else if (state.hasMore) {
          ref.read(commentsProvider(widget.request).notifier).loadNextPage();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(commentsProvider(widget.request));

    ref.listen<CommentsState>(commentsProvider(widget.request), (prev, next) {
      if (next.comments.length > (prev?.comments.length ?? 0)) {
        if (_displayCount >= (prev?.comments.length ?? 0)) {
          setState(() {
            _displayCount = next.comments.length;
          });
        }
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        int crossAxisCount = 1;
        if (width >= 1200) {
          crossAxisCount = 4;
        } else if (width >= 900) {
          crossAxisCount = 3;
        } else if (width >= 600) {
          crossAxisCount = 2;
        }

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
                      if (state.availableSources.length > 1) ...[
                        Expanded(
                          child: _buildSourceFilterMenu(
                            context,
                            state,
                            isMobile,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: _buildLanguageFilterMenu(
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
                          if (state.availableSources.length > 1) ...[
                            _buildSourceFilterMenu(context, state, isMobile),
                            const SizedBox(width: 12),
                          ],
                          _buildLanguageFilterMenu(context, state, isMobile),
                          const SizedBox(width: 12),
                          _buildSortMenu(context, state, isMobile),
                        ],
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Expanded(child: _buildContent(context, state, crossAxisCount)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    CommentsState state,
    int crossAxisCount,
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

    final itemsToShow = state.comments.take(_displayCount).toList();
    final bool showBottomLoader =
        state.isLoadingMore || (_displayCount < state.comments.length);

    if (crossAxisCount > 1) {
      return MasonryGridView.count(
        controller: _scrollController,
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        itemCount: itemsToShow.length + (showBottomLoader ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= itemsToShow.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              ),
            );
          }
          return CommentTile(comment: itemsToShow[index]);
        },
      );
    }

    return ListView.separated(
      controller: _scrollController,
      itemCount: itemsToShow.length + (showBottomLoader ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index >= itemsToShow.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            ),
          );
        }
        return CommentTile(comment: itemsToShow[index]);
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
        _scrollController.jumpTo(0);
        setState(() {
          _displayCount = 20;
        });
      },
      itemBuilder: (context) => [
        _buildPopupMenuItem(
          CommentSourceFilter.all,
          l10n.commentsFilterAllSources,
          state.sourceFilter,
        ),
        if (state.availableSources.contains(CommentSource.serializd))
          _buildPopupMenuItem(
            CommentSourceFilter.serializd,
            l10n.commentsSourceSerializd,
            state.sourceFilter,
          ),
        if (state.availableSources.contains(CommentSource.letterboxd))
          _buildPopupMenuItem(
            CommentSourceFilter.letterboxd,
            l10n.commentsSourceLetterboxd,
            state.sourceFilter,
          ),
      ],
      child: _buildFilterChip(label, Icons.layers_outlined, isMobile),
    );
  }

  Widget _buildLanguageFilterMenu(
    BuildContext context,
    CommentsState state,
    bool isMobile,
  ) {
    final l10n = AppLocalizations.of(context)!;
    String label = l10n.commentsFilterAnyLanguage;
    switch (state.languageFilter) {
      case CommentLanguageFilter.english:
        label = l10n.commentsFilterEnglish;
        break;
      case CommentLanguageFilter.italian:
        label = l10n.commentsFilterItalian;
        break;
      case CommentLanguageFilter.englishAndItalian:
        label = l10n.commentsFilterEnIt;
        break;
      case CommentLanguageFilter.unfiltered:
        label = l10n.commentsFilterAnyLanguage;
        break;
    }

    return PopupMenuButton<CommentLanguageFilter>(
      color: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (val) {
        ref
            .read(commentsProvider(widget.request).notifier)
            .setLanguageFilter(val);
        _scrollController.jumpTo(0);
        setState(() {
          _displayCount = 20;
        });
      },
      itemBuilder: (context) => [
        _buildPopupMenuItem(
          CommentLanguageFilter.unfiltered,
          l10n.commentsFilterAnyLanguage,
          state.languageFilter,
        ),
        _buildPopupMenuItem(
          CommentLanguageFilter.english,
          l10n.commentsFilterEnglish,
          state.languageFilter,
        ),
        _buildPopupMenuItem(
          CommentLanguageFilter.italian,
          l10n.commentsFilterItalian,
          state.languageFilter,
        ),
        _buildPopupMenuItem(
          CommentLanguageFilter.englishAndItalian,
          l10n.commentsFilterEnIt,
          state.languageFilter,
        ),
      ],
      child: _buildFilterChip(label, Icons.language, isMobile),
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
        _scrollController.jumpTo(0);
        setState(() {
          _displayCount = 20;
        });
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
  AppBottomSheet.show(
    context: context,
    heightFactor: 0.85,
    child: CommentsBottomSheet(request: request),
  );
}
