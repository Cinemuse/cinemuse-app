import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cinemuse_app/features/media/application/comments_provider.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/comment_tile.dart';

class CommentsBottomSheet extends ConsumerStatefulWidget {
  final CommentsRequest request;
  
  const CommentsBottomSheet({super.key, required this.request});
  
  @override
  ConsumerState<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
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
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final state = ref.read(tvTimeCommentsProvider(widget.request));
      if (!state.isLoading && _displayCount < state.comments.length) {
        setState(() {
          _displayCount += 20;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tvTimeCommentsProvider(widget.request));
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    
    int crossAxisCount = 1;
    if (width >= 1200) {
      crossAxisCount = 4;
    } else if (width >= 900) {
      crossAxisCount = 3;
    } else if (width >= 600) {
      crossAxisCount = 2;
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textWhite.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TVTime Comments',
                style: DesktopTypography.sectionHeader,
              ),
              if (!state.isLoading && state.hasAnyComments)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLanguageFilterMenu(context, state),
                    const SizedBox(width: 12),
                    _buildSortMenu(context, state),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _buildContent(state, crossAxisCount),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(TvTimeCommentsState state, int crossAxisCount) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
    }
    if (state.error != null) {
      return Center(
        child: Text(
          'Error loading comments: ${state.error}',
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    }
    if (state.comments.isEmpty) {
      return const Center(
        child: Text(
          'No comments found.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }

    final itemsToShow = state.comments.take(_displayCount).toList();

    if (crossAxisCount > 1) {
      return MasonryGridView.count(
        controller: _scrollController,
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        itemCount: itemsToShow.length + (_displayCount < state.comments.length ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= itemsToShow.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
            );
          }
          return CommentTile(comment: itemsToShow[index]);
        },
      );
    }

    return ListView.separated(
      controller: _scrollController,
      itemCount: itemsToShow.length + (_displayCount < state.comments.length ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index >= itemsToShow.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
          );
        }
        return CommentTile(comment: itemsToShow[index]);
      },
    );
  }

  Widget _buildLanguageFilterMenu(BuildContext context, TvTimeCommentsState state) {
    String label = 'Any Language';
    switch (state.languageFilter) {
      case CommentLanguageFilter.english: label = 'English'; break;
      case CommentLanguageFilter.italian: label = 'Italian'; break;
      case CommentLanguageFilter.englishAndItalian: label = 'EN + IT'; break;
      case CommentLanguageFilter.unfiltered: label = 'Any Language'; break;
    }

    return PopupMenuButton<CommentLanguageFilter>(
      color: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (val) {
        ref.read(tvTimeCommentsProvider(widget.request).notifier).setLanguageFilter(val);
        _scrollController.jumpTo(0);
        setState(() { _displayCount = 20; });
      },
      itemBuilder: (context) => [
        _buildPopupMenuItem(CommentLanguageFilter.unfiltered, 'Any Language', state.languageFilter),
        _buildPopupMenuItem(CommentLanguageFilter.english, 'English', state.languageFilter),
        _buildPopupMenuItem(CommentLanguageFilter.italian, 'Italian', state.languageFilter),
        _buildPopupMenuItem(CommentLanguageFilter.englishAndItalian, 'English + Italian', state.languageFilter),
      ],
      child: _buildFilterChip(label, Icons.language),
    );
  }

  Widget _buildSortMenu(BuildContext context, TvTimeCommentsState state) {
    String label = state.sortType == CommentSortType.mostLiked ? 'Most Liked' : 'Recent';

    return PopupMenuButton<CommentSortType>(
      color: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (val) {
        ref.read(tvTimeCommentsProvider(widget.request).notifier).setSortType(val);
        _scrollController.jumpTo(0);
        setState(() { _displayCount = 20; });
      },
      itemBuilder: (context) => [
        _buildPopupMenuItem(CommentSortType.mostLiked, 'Most Liked', state.sortType),
        _buildPopupMenuItem(CommentSortType.recent, 'Recent', state.sortType),
      ],
      child: _buildFilterChip(label, Icons.sort),
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.textWhite.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.textWhite.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppTheme.textWhite),
          const SizedBox(width: 8),
          Text(
            label,
            style: DesktopTypography.bodySecondary.copyWith(
              fontSize: 14,
              color: AppTheme.textWhite,
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<T> _buildPopupMenuItem<T>(T value, String label, T currentValue) {
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
  final width = MediaQuery.of(context).size.width;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    constraints: BoxConstraints(
      maxWidth: width > 1200 ? 1200 : width,
    ),
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.85,
      child: CommentsBottomSheet(request: request),
    ),
  );
}
