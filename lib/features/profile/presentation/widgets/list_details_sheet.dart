import 'package:cinemuse_app/core/constants/app_constants.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:cinemuse_app/shared/widgets/app_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';

class ListDetailsSheet extends ConsumerStatefulWidget {
  final UserList list;
  final Function(String name, String? description)? onUpdate;
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
    Function(String name, String? description)? onUpdate,
    VoidCallback? onDelete,
  }) {
    AppBottomSheet.show(
      context: context,
      heightFactor: 0.9,
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

  bool _isSystemList(UserList list) =>
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

  void _saveChanges() {
    final l10n = AppLocalizations.of(context)!;
    if (widget.onUpdate != null) {
      widget.onUpdate!(
        _titleController.text.trim().isEmpty
            ? l10n.listUntitled
            : _titleController.text.trim(),
        _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
      );
    }
    setState(() {
      _isEditing = false;
    });
  }

  Widget _buildTitle(UserList list) {
    final l10n = AppLocalizations.of(context)!;
    if (_isEditing) {
      return TextField(
        controller: _titleController,
        focusNode: _titleFocus,
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
        onSubmitted: (_) => FocusScope.of(context).requestFocus(_descFocus),
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
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: AppTheme.accent.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
        ),
        child: TextField(
          controller: _descController,
          focusNode: _descFocus,
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
      );
    }

    final hasDescription =
        _isSystemList(list) ||
        _descController.text.isNotEmpty ||
        (list.description?.isNotEmpty ?? false);

    if (hasDescription) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.only(left: 16),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: AppTheme.accent.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                _displaySubtitle(list),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
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

    // Watch the lists provider to reflect item removals immediately
    final userListsState = ref.watch(userListsProvider);
    final currentList =
        userListsState.valueOrNull?.firstWhere(
          (l) => l.id == widget.list.id,
          orElse: () => widget.list,
        ) ??
        widget.list;

    // Determine icon and color based on list type
    final isSystemList =
        currentList.type == ListType.watchlist ||
        currentList.type == ListType.favorites;
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
      blurSigma: 16.0,
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
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
                    // Actions
                    if (_isEditing)
                      IconButton(
                        onPressed: _saveChanges,
                        icon: const Icon(
                          LucideIcons.check,
                          color: AppTheme.accent,
                          size: 28,
                        ),
                      )
                    else ...[
                      IconButton(
                        tooltip: ref.watch(pinnedListIdsProvider).contains(currentList.id)
                            ? l10n.listUnpinFromHome
                            : l10n.listPinToHome,
                        onPressed: () {
                          final pinnedIds = ref.read(pinnedListIdsProvider);
                          final isPinned = pinnedIds.contains(currentList.id);
                          ref.read(pinnedListIdsProvider.notifier).togglePin(currentList.id);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isPinned
                                    ? l10n.listUnpinnedSuccess
                                    : l10n.listPinnedSuccess,
                              ),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: AppTheme.surface,
                            ),
                          );
                        },
                        icon: Icon(
                          LucideIcons.pin,
                          color: ref.watch(pinnedListIdsProvider).contains(currentList.id)
                              ? AppTheme.accent
                              : Colors.white54,
                          size: 22,
                        ),
                      ),
                      if (!isSystemList && widget.onUpdate != null)
                        PopupMenuButton<String>(
                          icon: const Icon(
                            LucideIcons.moreVertical,
                            color: Colors.white54,
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
                            PopupMenuItem(
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
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(
                                      LucideIcons.trash2,
                                      size: 18,
                                      color: Colors.redAccent,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      l10n.detailsDeleteList,
                                      style: const TextStyle(
                                        color: Colors.redAccent,
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
                : GridView.builder(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      24,
                      24,
                      24 + MediaQuery.paddingOf(context).bottom,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: currentList.items.length,
                    itemBuilder: (context, index) {
                      return _ListMediaCard(
                        item: currentList.items[index],
                        listId: currentList.id,
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
  final String listId;

  const _ListMediaCard({required this.item, required this.listId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context)!;

    // Initial local fallback values
    String title =
        item.media?.getLocalizedTitle(locale) ??
        (item.meta['title'] as String? ?? l10n.commonUnknown);
    String? posterPath =
        item.media?.posterPath ?? (item.meta['poster_path'] as String?);
    double? rating =
        item.media?.voteAverage ?? (item.meta['rating'] as num?)?.toDouble();
    String? year =
        item.media?.releaseDate?.year.toString() ??
        item.meta['year']?.toString();

    // If local title is still missing/Unknown, attempt a lazy patch
    if (title.isEmpty || title == l10n.commonUnknown || title == 'Unknown') {
      // Use mediaItemProvider for initial render if cache exists
      final asyncMedia = ref.watch(
        mediaItemProvider((id: item.tmdbId, type: item.mediaType)),
      );
      final fetchedMedia = asyncMedia.valueOrNull;

      if (fetchedMedia != null) {
        final newTitle = fetchedMedia.getLocalizedTitle(locale);
        if (newTitle != null && newTitle.isNotEmpty) {
          title = newTitle;
          posterPath = fetchedMedia.posterPath ?? posterPath;
          rating = fetchedMedia.voteAverage ?? rating;
          year = fetchedMedia.releaseDate?.year.toString() ?? year;
        } else {
          // The cached item itself is stale/incomplete (null titles).
          // Force a fresh TMDB fetch to overwrite the cache permanently.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(
              mediaDetailsProvider((
                id: item.tmdbId.toString(),
                type: item.mediaType.name,
              )),
            );
          });
        }
      } else if (!asyncMedia.isLoading && !asyncMedia.hasError) {
        // Not in cache, force fetch
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(
            mediaDetailsProvider((
              id: item.tmdbId.toString(),
              type: item.mediaType.name,
            )),
          );
        });
      }
    }

    return MediaCard(
      title: title,
      posterPath: posterPath,
      rating: rating,
      releaseDate: year,
      tmdbId: item.tmdbId,
      mediaType: item.mediaType,
      onRemoveFromList: () {
        ref
            .read(userListsProvider.notifier)
            .removeItemFromList(listId, item.tmdbId, item.mediaType);
      },
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
