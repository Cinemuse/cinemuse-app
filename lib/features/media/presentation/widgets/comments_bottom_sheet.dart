import 'package:cinemuse_app/core/data/server_addresses_model.dart';
import 'package:cinemuse_app/core/data/server_addresses_repository.dart';
import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/application/comments_provider.dart';
import 'package:cinemuse_app/features/media/application/own_reviews_provider.dart';
import 'package:cinemuse_app/features/media/domain/comment.dart';
import 'package:cinemuse_app/features/media/domain/comments_repository.dart';
import 'package:cinemuse_app/features/media/domain/own_review.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/comment_filter_menus.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/comment_tile.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/own_review_action.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/own_review_editor.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/own_review_tile.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/action_feedback.dart';
import 'package:cinemuse_app/shared/widgets/app_bottom_sheet.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';

class CommentsBottomSheet extends ConsumerStatefulWidget {
  final CommentsRequest request;

  const CommentsBottomSheet({super.key, required this.request});

  @override
  ConsumerState<CommentsBottomSheet> createState() =>
      _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends ConsumerState<CommentsBottomSheet> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _revealedSpoilerIds = {};

  /// The own review's button, where the focus returns when the editor closes.
  final _ownReviewButtonNode = FocusNode(debugLabel: 'OwnReviewButton');
  bool _isEditing = false;

  /// The unsaved text the editor opens with.
  OwnReviewDraft? _draft;

  /// Where the list is scrolling to, while it does: a quick press counts
  /// from there, not from halfway.
  double? _scrollTarget;

  // Kept: it remembers the way the remote came, to go back the same way.
  late final _traversalPolicy = ReadingOrderTraversalPolicy(
    requestFocusCallback: _focusStop,
  );

  /// The space kept between a comment the remote scrolls to and the list's
  /// edge.
  static const _revealMargin = 24.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _ownReviewButtonNode.dispose();
    super.dispose();
  }

  /// The title a rating would belong to; an episode's reviews have none.
  RatedTitle? get _ratedTitle => switch (widget.request) {
    final MediaReviewsRequest request => (
      tmdbId: request.tmdbId,
      mediaType: request.mediaType,
    ),
    _ => null,
  };

  Future<void> _openEditor(RatedTitle title) async {
    final draft = await ref
        .read(ownReviewActionsProvider)
        .loadDraft(title, saved: ref.read(visibleOwnReviewProvider(title)));
    if (!mounted) return;
    setState(() {
      _draft = draft;
      _isEditing = true;
    });
  }

  void _closeEditor() {
    setState(() => _isEditing = false);
    // The button is back only after the next build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ownReviewButtonNode.requestFocus();
    });
  }

  void _removeOwnReview(OwnReview review) {
    _closeEditor();
    final l10n = AppLocalizations.of(context)!;
    // Not awaited: it lasts as long as the Undo message.
    unawaited(
      runShowingErrors(
        context,
        ref,
        () => ref
            .read(ownReviewActionsProvider)
            .removeWithUndo(
              review,
              undone: AppSnackBar.showUndo(
                context,
                message: l10n.ownReviewRemoved,
              ),
            ),
      ),
    );
  }

  void _discardChanges(RatedTitle title) {
    _closeEditor();
    final l10n = AppLocalizations.of(context)!;
    // Not awaited: it lasts as long as the Undo message.
    unawaited(
      runShowingErrors(
        context,
        ref,
        () => ref
            .read(ownReviewActionsProvider)
            .discardDraftWithUndo(
              title,
              undone: AppSnackBar.showUndo(
                context,
                message: l10n.ownReviewChangesDiscarded,
              ),
            ),
      ),
    );
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
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

  /// The comment of [node] and the list's offsets that show its top and its
  /// bottom; null for a stop outside the list (the filters).
  ({ScrollPosition position, double top, double bottom})? _revealOffsets(
    FocusNode? node,
  ) {
    final context = node?.context;
    final box = context?.findRenderObject();
    if (context == null || box == null || !_scrollController.hasClients) {
      return null;
    }
    if (Scrollable.maybeOf(context)?.position != _scrollController.position) {
      return null;
    }
    final viewport = RenderAbstractViewport.of(box);
    return (
      position: _scrollController.position,
      top: viewport.getOffsetToReveal(box, 0).offset - _revealMargin,
      bottom: viewport.getOffsetToReveal(box, 1).offset + _revealMargin,
    );
  }

  /// Slides the list to [offset], or jumps there with [jump]: a slide still
  /// running when the focus moves would leave the next comment unbuilt.
  void _scrollTo(ScrollPosition position, double offset, {bool jump = false}) {
    final target = offset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (jump) {
      _scrollTarget = null;
      position.jumpTo(target);
      return;
    }
    if ((target - position.pixels).abs() < 1) return;
    _scrollTarget = target;
    unawaited(
      position
          .animateTo(
            target,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            if (_scrollTarget == target) _scrollTarget = null;
          }),
    );
  }

  /// Moves the focus for the arrows and Tab, and scrolls the list to the
  /// comment: all of it when it fits, else its start when the remote comes
  /// from above and its end from below. Flutter showed the edge nearest the
  /// move: Down skipped a long comment's start, and the comment above was
  /// then too far to be built, so Up found nothing.
  void _focusStop(
    FocusNode node, {
    ScrollPositionAlignmentPolicy? alignmentPolicy,
    double? alignment,
    Duration? duration,
    Curve? curve,
  }) {
    node.requestFocus();
    final reveal = _revealOffsets(node);
    if (reveal == null) return;
    final (:position, :top, :bottom) = reveal;
    final current = _scrollTarget ?? position.pixels;
    final isUp =
        alignmentPolicy == ScrollPositionAlignmentPolicy.keepVisibleAtStart;
    _scrollTo(
      position,
      bottom <= top ? current.clamp(bottom, top) : (isUp ? bottom : top),
      jump: true,
    );
  }

  /// Up and Down on a comment taller than the list scroll through it, most
  /// of a screen at a time; once its edge shows, they move to the next stop.
  KeyEventResult _scrollThroughComment(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final isDown = event.logicalKey == LogicalKeyboardKey.arrowDown;
    if (!isDown && event.logicalKey != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    final reveal = _revealOffsets(FocusManager.instance.primaryFocus);
    if (reveal == null) return KeyEventResult.ignored;
    final (:position, :top, :bottom) = reveal;
    final current = _scrollTarget ?? position.pixels;
    final edge = (isDown ? bottom : top).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    final left = edge - current;
    if (isDown ? left < 1 : left > -1) return KeyEventResult.ignored;
    final step = position.viewportDimension * 0.7;
    _scrollTo(position, current + left.clamp(-step, step));
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(commentsProvider(widget.request));
    // The series review site's name comes from the server's list.
    final seriesSite =
        (ref.watch(serverAddressesProvider).value ?? ServerAddresses.empty)
            .name(ServerAddress.reviews);
    final ratedTitle = _ratedTitle;
    // Watched even while the editor is open, so it isn't read again after.
    final ownReview = ratedTitle == null
        ? null
        : ref.watch(visibleOwnReviewProvider(ratedTitle));
    final ownReviewAction = ratedTitle == null
        ? null
        : OwnReviewAction(
            title: ratedTitle,
            focusNode: _ownReviewButtonNode,
            onEdit: () => unawaited(_openEditor(ratedTitle)),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final bool isMobile = width < Breakpoints.compact;
        final sourceMenu = CommentSourceFilterMenu(
          request: widget.request,
          isMobile: isMobile,
          seriesSite: seriesSite,
          onChanged: _scrollToTop,
        );
        final sortMenu = CommentSortMenu(
          request: widget.request,
          isMobile: isMobile,
          onChanged: _scrollToTop,
        );

        return AppBottomSheet(
          backgroundColor: AppTheme.primary,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          // Back while editing returns to the reviews, as Cancel does.
          child: PopScope(
            canPop: !_isEditing,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _closeEditor();
            },
            child: _isEditing && ratedTitle != null
                ? OwnReviewEditor(
                    title: ratedTitle,
                    review: ownReview,
                    draft: _draft,
                    onClose: _closeEditor,
                    onDiscard: () => _discardChanges(ratedTitle),
                    onRemove: _removeOwnReview,
                  )
                : FocusTraversalGroup(
                    policy: _traversalPolicy,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8), // Extra space after handle
                        if (isMobile) ...[
                          Text(
                            l10n.detailsTvTimeComments,
                            style: DesktopTypography.sectionHeader,
                          ),
                          if (ownReviewAction != null) ...[
                            const SizedBox(height: 16),
                            ownReviewAction,
                          ],
                          if (!state.isLoading && state.hasAnyComments) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(child: sourceMenu),
                                const SizedBox(width: 8),
                                Expanded(child: sortMenu),
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
                                    sourceMenu,
                                    const SizedBox(width: 12),
                                    sortMenu,
                                  ],
                                ),
                            ],
                          ),
                          if (ownReviewAction != null) ...[
                            const SizedBox(height: 12),
                            ownReviewAction,
                          ],
                        ],
                        const SizedBox(height: 24),
                        Expanded(
                          child: _buildContent(
                            context,
                            state,
                            seriesSite,
                            ownReview,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    CommentsState state,
    String seriesSite,
    OwnReview? ownReview,
  ) {
    final l10n = AppLocalizations.of(context)!;

    final comments = state.comments;
    // Shown when the list can't reach the scroll trigger (empty or short
    // after a filter) but more pages exist (REV-209).
    final Widget? listEnd = state.isLoadingMore
        ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
        : state.hasMore
        ? Center(
            child: TextButton.icon(
              onPressed: () => ref
                  .read(commentsProvider(widget.request).notifier)
                  .loadNextPage(),
              icon: const Icon(Icons.expand_more),
              label: Text(l10n.commentsLoadMore),
            ),
          )
        : null;
    // What shows when there are no comments to list.
    final Widget? noComments = state.isLoading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
        : state.error != null
        ? Text(
            '${l10n.tvTimeCommentsError} (${ref.watch(errorMapperProvider).map(state.error!).message})',
            style: const TextStyle(color: AppTheme.favorites),
          )
        : comments.isNotEmpty
        ? null
        : listEnd ??
              Text(
                l10n.tvTimeNoComments,
                style: const TextStyle(color: AppTheme.textMuted),
              );

    if (noComments != null && ownReview == null) {
      return Center(child: noComments);
    }

    // The user's own review comes first and never depends on the outside
    // ones: they may be loading, or have failed.
    final ownCount = ownReview == null ? 0 : 1;
    final items = noComments == null ? comments : const <Comment>[];
    final listFooter = noComments ?? listEnd;

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _scrollThroughComment,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: ownCount + items.length + (listFooter != null ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (ownReview != null && index == 0) {
            return OwnReviewTile(review: ownReview);
          }
          final i = index - ownCount;
          if (i >= items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(child: listFooter),
            );
          }
          final comment = items[i];
          return CommentTile(
            key: ValueKey(comment.id),
            comment: comment,
            seriesSite: seriesSite,
            isSpoilerRevealed: _revealedSpoilerIds.contains(comment.id),
            onRevealSpoiler: () =>
                setState(() => _revealedSpoilerIds.add(comment.id)),
          );
        },
      ),
    );
  }
}

void showCommentsBottomSheet(BuildContext context, CommentsRequest request) {
  AppBottomSheet.show(
    context: context,
    heightFactor: 0.85,
    constraints: const BoxConstraints(maxWidth: Breakpoints.compact),
    child: CommentsBottomSheet(request: request),
  );
}
