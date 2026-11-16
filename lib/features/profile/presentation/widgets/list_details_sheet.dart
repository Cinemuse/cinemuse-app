import 'dart:async';
import 'package:cinemuse_app/features/profile/application/title_marks_provider.dart';

import 'package:cinemuse_app/core/constants/app_constants.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:cinemuse_app/shared/widgets/app_bottom_sheet.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:cinemuse_app/shared/widgets/menu/menu_focus_ring.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/shared/widgets/dpad_text_box.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/list_action_feedback.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/list_pin_action.dart';
import 'package:cinemuse_app/features/profile/application/pinned_list_ids_provider.dart';
import 'package:cinemuse_app/features/search/presentation/search_overlay.dart';

/// Saves a rename; completes with whether it was saved.
typedef ListRename = Future<bool> Function(String name, String? description);

class ListDetailsSheet extends ConsumerStatefulWidget {
  final UserList list;
  final ListRename? onUpdate;
  final VoidCallback? onDelete;

  const ListDetailsSheet({
    super.key,
    required this.list,
    this.onUpdate,
    this.onDelete,
  });

  static void show(
    BuildContext context, {
    required UserList list,
    ListRename? onUpdate,
    VoidCallback? onDelete,
  }) {
    AppBottomSheet.show(
      context: context,
      heightFactor: 0.9,
      // On the shell's navigator, so a title opened from the list keeps the
      // top bar and Back returns to the sheet (REV-267).
      useRootNavigator: false,
      child: ListDetailsSheet(
        list: list,
        onUpdate: onUpdate,
        onDelete: onDelete,
      ),
    );
  }

  @override
  ConsumerState<ListDetailsSheet> createState() => _ListDetailsSheetState();
}

class _ListDetailsSheetState extends ConsumerState<ListDetailsSheet> {
  bool _isEditing = false;
  bool _isDescExpanded = false;

  bool _hasFixedSubtitle(UserList list) =>
      list.type == ListType.watchlist || list.type == ListType.favorites;

  String _displayTitle(UserList list) {
    final l10n = AppLocalizations.of(context)!;
    if (list.type == ListType.watchlist) return l10n.listWatchLater;
    if (list.type == ListType.favorites) return l10n.listFavorites;
    return _titleController.text.isEmpty ? list.name : _titleController.text;
  }

  String _displaySubtitle(UserList list) {
    final l10n = AppLocalizations.of(context)!;
    if (list.type == ListType.watchlist) return l10n.listYourQueue;
    if (list.type == ListType.favorites) return l10n.listCuratedPicks;
    return _descController.text.isEmpty
        ? (list.description ?? '')
        : _descController.text;
  }

  late TextEditingController _titleController;
  late TextEditingController _descController;
  late FocusNode _titleFocus;
  late FocusNode _descFocus;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.list.name);
    _descController = TextEditingController(
      text: widget.list.description ?? '',
    );
    _titleFocus = FocusNode();
    _descFocus = FocusNode();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _titleFocus.dispose();
    _descFocus.dispose();
    super.dispose();
  }

  // A rename that wasn't saved keeps the boxes open with the typed text
  // (REV-89); the error message comes from [ListDetailsSheet.onUpdate].
  Future<void> _saveChanges() async {
    final l10n = AppLocalizations.of(context)!;
    final isSaved =
        await widget.onUpdate?.call(
          _titleController.text.trim().isEmpty
              ? l10n.listUntitled
              : _titleController.text.trim(),
          _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
        ) ??
        true;
    if (!mounted || !isSaved) return;
    setState(() {
      _isEditing = false;
    });
  }

  /// Takes [item] out of [list], with Undo. Runs here, not in the card: the
  /// card goes with the title, this sheet stays to show a failure.
  Future<void> _removeTitle(UserList list, UserListItem item, String title) {
    final undone = AppSnackBar.showUndo(
      context,
      message: AppLocalizations.of(context)!.listTitleRemoved(title),
    );
    return runListAction(
      context,
      ref,
      (lists) => lists.removeItemWithUndo(
        list.id,
        item.tmdbId,
        item.mediaType,
        undone: undone,
      ),
    );
  }

  Widget _buildTitle(UserList list) {
    final l10n = AppLocalizations.of(context)!;
    if (_isEditing) {
      return DpadTextBox(
        textFocusNode: _titleFocus,
        borderRadius: AppTheme.radiusSm,
        builder: (context, textNode, stopTyping) => TextField(
          controller: _titleController,
          focusNode: textNode,
          maxLength: AppConstants.maxListNameLength,
          buildCounter:
              (
                context, {
                required currentLength,
                required isFocused,
                required maxLength,
              }) => null,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            hintText: l10n.listNameHint,
            hintStyle: const TextStyle(color: Colors.white54),
          ),
          textInputAction: TextInputAction.next,
          // Goes on typing in the description.
          onEditingComplete: _descFocus.requestFocus,
        ),
      );
    }

    return Text(
      _displayTitle(list),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildDescription(UserList list) {
    final l10n = AppLocalizations.of(context)!;
    if (_isEditing) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.only(left: 16),
        decoration: _descriptionBoxDecoration,
        child: DpadTextBox(
          textFocusNode: _descFocus,
          isMultiline: true,
          borderRadius: AppTheme.radiusSm,
          builder: (context, textNode, stopTyping) => TextField(
            controller: _descController,
            focusNode: textNode,
            maxLines: null,
            maxLength: AppConstants.maxListDescriptionLength,
            buildCounter:
                (
                  context, {
                  required currentLength,
                  required isFocused,
                  required maxLength,
                }) {
                  return Text(
                    '$currentLength / $maxLength',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  );
                },
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              hintText: l10n.listDescriptionHint,
              hintStyle: const TextStyle(color: Colors.white54),
            ),
          ),
        ),
      );
    }

    final hasDescription =
        _hasFixedSubtitle(list) ||
        _descController.text.isNotEmpty ||
        (list.description?.isNotEmpty ?? false);

    if (hasDescription) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.only(left: 16),
        decoration: _descriptionBoxDecoration,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final subtitleStyle = TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  );
                  final textSpan = TextSpan(
                    text: _displaySubtitle(list),
                    style: subtitleStyle,
                  );
                  final textPainter = TextPainter(
                    text: textSpan,
                    maxLines: 3,
                    textDirection: TextDirection.ltr,
                  )..layout(maxWidth: constraints.maxWidth);

                  final isOverflowing = textPainter.didExceedMaxLines;

                  return AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displaySubtitle(list),
                          style: subtitleStyle,
                          maxLines: _isDescExpanded ? null : 3,
                          overflow: _isDescExpanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                        ),
                        if (isOverflowing)
                          DpadFocusable(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () => setState(
                              () => _isDescExpanded = !_isDescExpanded,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _isDescExpanded
                                    ? l10n.detailsShowLess
                                    : l10n.detailsReadMore,
                                style: const TextStyle(
                                  color: AppTheme.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Watch the corresponding provider to reflect item removals immediately
    UserList currentList;
    if (widget.list.type == ListType.dropped) {
      final droppedListState = ref.watch(droppedListProvider);
      currentList = droppedListState.value ?? widget.list;
    } else {
      final userListsState = ref.watch(userListsProvider);
      currentList =
          userListsState.value?.firstWhere(
            (l) => l.id == widget.list.id,
            orElse: () => widget.list,
          ) ??
          widget.list;
    }

    final isSystemList = currentList.isSystemList;
    final isReadOnly = currentList.isReadOnly;
    final isPinned = ref.watch(pinnedListIdsProvider).contains(currentList.id);
    final icon = currentList.type == ListType.watchlist
        ? LucideIcons.bookmark
        : (currentList.type == ListType.favorites
              ? LucideIcons.heart
              : LucideIcons.list);

    final iconColor = currentList.type == ListType.watchlist
        ? AppTheme.watchlist
        : (currentList.type == ListType.favorites
              ? AppTheme.favorites
              : Colors.white);

    return AppBottomSheet(
      backgroundColor: AppTheme.surface.withValues(alpha: 0.9),
      blurSigma: 8.0,
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Icon(icon, color: iconColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTitle(currentList),
                          const SizedBox(height: 4),
                          Text(
                            l10n.listItemsCount(currentList.items.length),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_isEditing)
                      IconButton(
                        tooltip: l10n.settingsSave,
                        onPressed: _saveChanges,
                        icon: const Icon(
                          LucideIcons.check,
                          color: AppTheme.accent,
                          size: 28,
                        ),
                      )
                    else ...[
                      // Home never shows Dropped, so it has no pin (REV-311).
                      if (currentList.type != ListType.dropped)
                        IconButton(
                          tooltip: isPinned
                              ? l10n.listUnpinFromHome
                              : l10n.listPinToHome,
                          onPressed: () => togglePinWithFeedback(
                            context,
                            ref,
                            currentList.id,
                          ),
                          icon: Icon(
                            LucideIcons.pin,
                            color: isPinned ? AppTheme.accent : Colors.white54,
                            size: 22,
                          ),
                        ),
                      if (currentList.type != ListType.dropped && !isReadOnly)
                        IconButton(
                          tooltip: l10n.searchPlaceholder,
                          onPressed: () {
                            SearchOverlay.show(
                              context,
                              onItemSelected: (media) => runListAction(
                                context,
                                ref,
                                (lists) =>
                                    lists.addFromSearch(currentList, media),
                              ),
                            );
                          },
                          icon: const Icon(
                            LucideIcons.plus,
                            color: Colors.white54,
                            size: 22,
                          ),
                        ),
                      if (!isSystemList && widget.onUpdate != null)
                        PopupMenuButton<String>(
                          tooltip: l10n.menuMoreOptions,
                          icon: const Icon(
                            LucideIcons.moreVertical,
                            color: Colors.white54,
                          ),
                          style: ButtonStyle(
                            overlayColor: AppTheme.hoverOverlay(),
                          ),
                          color: AppTheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onSelected: (value) {
                            if (value == 'edit') {
                              setState(() => _isEditing = true);
                              _titleFocus.requestFocus();
                            } else if (value == 'delete') {
                              FocusManager.instance.primaryFocus?.unfocus();
                              Navigator.of(context).pop();
                              if (widget.onDelete != null) widget.onDelete!();
                            }
                          },
                          itemBuilder: (context) => [
                            AppPopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  const Icon(
                                    LucideIcons.edit3,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    l10n.detailsEditList,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.onDelete != null)
                              AppPopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(
                                      LucideIcons.trash2,
                                      size: 18,
                                      color: AppTheme.error,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      l10n.detailsDeleteList,
                                      style: const TextStyle(
                                        color: AppTheme.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                    ],
                  ],
                ),
                _buildDescription(currentList),
              ],
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          // Content
          Expanded(
            child: currentList.items.isEmpty
                ? Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.paddingOf(context).bottom,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icon,
                            size: 64,
                            color: iconColor.withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.listEmptyTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.listEmptyMessage,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile =
                          constraints.maxWidth < Breakpoints.compact;
                      final spacing = isMobile ? 10.0 : 16.0;
                      final padding = isMobile ? 16.0 : 24.0;

                      return GridView.builder(
                        addAutomaticKeepAlives: true,
                        padding: EdgeInsets.fromLTRB(
                          padding,
                          padding,
                          padding,
                          padding + MediaQuery.paddingOf(context).bottom,
                        ),
                        gridDelegate: isMobile
                            ? SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 0.54,
                                crossAxisSpacing: spacing,
                                mainAxisSpacing: spacing,
                              )
                            : const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 180,
                                childAspectRatio: 0.56,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                        itemCount: currentList.items.length,
                        itemBuilder: (context, index) {
                          final item = currentList.items[index];
                          return _ListMediaCard(
                            item: item,
                            list: currentList,
                            // Dropped is a label, not a list: its titles
                            // only leave it through Restore (REV-262).
                            onRemove:
                                currentList.isReadOnly ||
                                    currentList.type == ListType.dropped
                                ? null
                                : (title) =>
                                      _removeTitle(currentList, item, title),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ListMediaCard extends ConsumerWidget {
  final UserListItem item;
  final UserList list;

  /// Called with the title's shown name; null where titles can't be removed.
  final ValueChanged<String>? onRemove;

  const _ListMediaCard({
    required this.item,
    required this.list,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context)!;

    // A title missing from the local cache, or cached without its rating,
    // is fetched in full (and cached), so the card shows rating and year
    // on first open (REV-270).
    final cached = item.media;
    final isComplete =
        cached != null &&
        cached.hasCompleteTitle(locale) &&
        cached.voteAverage != null;
    final media = isComplete
        ? cached
        : ref
                  .watch(
                    mediaItemProvider((id: item.tmdbId, type: item.mediaType)),
                  )
                  .value ??
              cached;

    final title = media?.getLocalizedTitle(locale) ?? l10n.commonUnknown;
    final onRemove = this.onRemove;
    return MediaCard(
      title: title,
      posterPath: media?.posterPath,
      rating: media?.voteAverage,
      releaseDate: media?.releaseDate?.year.toString(),
      marks: ref.watch(
        titleMarksProvider((
          tmdbId: item.tmdbId,
          mediaType: item.mediaType,
          place: MarksPlace.ofList(list.type),
        )),
      ),
      onRemoveFromList: onRemove == null ? null : () => onRemove(title),
      onRestore: list.type == ListType.dropped
          ? () async {
              await runListAction(
                context,
                ref,
                (lists) =>
                    lists.restoreFromDropped(item.tmdbId, item.mediaType),
              );
            }
          : null,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MediaDetailsScreen(
              mediaId: item.tmdbId.toString(),
              mediaType: item.mediaType.name,
            ),
          ),
        );
      },
    );
  }
}

/// The accent line left of the description, read or edited.
final _descriptionBoxDecoration = BoxDecoration(
  border: Border(
    left: BorderSide(color: AppTheme.accent.withValues(alpha: 0.5), width: 2),
  ),
);
