import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:cinemuse_app/shared/widgets/app_bottom_sheet.dart';
import 'package:flutter/material.dart';
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

  bool _isSystemList(UserList list) => list.type == ListType.watchlist || list.type == ListType.favorites;
  
  String _displayTitle(UserList list) {
    if (list.type == ListType.watchlist) return "Watch Later";
    if (list.type == ListType.favorites) return "Favorites";
    return _titleController.text.isEmpty ? list.name : _titleController.text;
  }

  String _displaySubtitle(UserList list) {
    if (list.type == ListType.watchlist) return "Your queue";
    if (list.type == ListType.favorites) return "Your curated picks";
    return _descController.text.isEmpty ? (list.description ?? '') : _descController.text;
  }

  late TextEditingController _titleController;
  late TextEditingController _descController;
  late FocusNode _titleFocus;
  late FocusNode _descFocus;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.list.name);
    _descController = TextEditingController(text: widget.list.description ?? '');
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
    if (widget.onUpdate != null) {
      widget.onUpdate!(
        _titleController.text.trim().isEmpty ? 'Untitled List' : _titleController.text.trim(),
        _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      );
    }
    setState(() {
      _isEditing = false;
    });
  }

  Widget _buildTitle(UserList list) {
    if (_isEditing) {
      return TextField(
        controller: _titleController,
        focusNode: _titleFocus,
        maxLength: 50,
        buildCounter: (context, {required currentLength, required isFocused, required maxLength}) => null,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 0),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          hintText: 'List Name',
          hintStyle: TextStyle(color: Colors.white54),
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
    if (_isEditing) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.only(left: 16),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: AppTheme.accent.withValues(alpha: 0.5), width: 2),
          ),
        ),
        child: TextField(
          controller: _descController,
          focusNode: _descFocus,
          maxLines: null,
          maxLength: 1000,
          buildCounter: (context, {required currentLength, required isFocused, required maxLength}) {
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
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            hintText: 'Add a description...',
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    final hasDescription = _isSystemList(list) || _descController.text.isNotEmpty || (list.description?.isNotEmpty ?? false);

    if (hasDescription) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.only(left: 16),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: AppTheme.accent.withValues(alpha: 0.5), width: 2),
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
    // Watch the lists provider to reflect item removals immediately
    final userListsState = ref.watch(userListsProvider);
    final currentList = userListsState.valueOrNull?.firstWhere(
      (l) => l.id == widget.list.id,
      orElse: () => widget.list,
    ) ?? widget.list;

    // Determine icon and color based on list type
    final isSystemList = currentList.type == ListType.watchlist || currentList.type == ListType.favorites;
    final icon = currentList.type == ListType.watchlist 
        ? LucideIcons.bookmark 
        : (currentList.type == ListType.favorites ? LucideIcons.heart : LucideIcons.list);
    
    final iconColor = currentList.type == ListType.watchlist 
        ? AppTheme.watchlist 
        : (currentList.type == ListType.favorites ? AppTheme.favorites : Colors.white);

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
                            '${currentList.items.length} items',
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
                    if (!isSystemList && widget.onUpdate != null) ...[
                      if (_isEditing)
                        IconButton(
                          onPressed: _saveChanges,
                          icon: const Icon(LucideIcons.check, color: AppTheme.accent, size: 28),
                        )
                      else
                        PopupMenuButton<String>(
                          icon: const Icon(LucideIcons.moreVertical, color: Colors.white54),
                          color: AppTheme.surface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(LucideIcons.edit3, size: 18, color: Colors.white),
                                  SizedBox(width: 12),
                                  Text('Edit List', style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                            if (widget.onDelete != null)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(LucideIcons.trash2, size: 18, color: Colors.redAccent),
                                    SizedBox(width: 12),
                                    Text('Delete List', style: TextStyle(color: Colors.redAccent)),
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
                    padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, size: 64, color: iconColor.withValues(alpha: 0.2)),
                          const SizedBox(height: 16),
                          const Text(
                            "This list is empty",
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Add media from the details page",
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
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
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
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

  const _ListMediaCard({
    required this.item,
    required this.listId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context).languageCode;
    
    // Initial local fallback values
    String title = item.media?.getLocalizedTitle(locale) ?? (item.meta['title'] as String? ?? 'Unknown');
    String? posterPath = item.media?.posterPath ?? (item.meta['poster_path'] as String?);
    double? rating = item.media?.voteAverage ?? (item.meta['rating'] as num?)?.toDouble();
    String? year = item.media?.releaseDate?.year.toString() ?? item.meta['year']?.toString();

    // If local title is still missing/Unknown, fetch from TMDB lazily
    if (title.isEmpty || title == 'Unknown') {
      final asyncMedia = ref.watch(mediaItemProvider((id: item.tmdbId, type: item.mediaType)));
      final fetchedMedia = asyncMedia.valueOrNull;
      if (fetchedMedia != null) {
        title = fetchedMedia.getLocalizedTitle(locale) ?? 'Unknown';
        posterPath = fetchedMedia.posterPath ?? posterPath;
        rating = fetchedMedia.voteAverage ?? rating;
        year = fetchedMedia.releaseDate?.year.toString() ?? year;
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
        ref.read(userListsProvider.notifier).removeItemFromList(
          listId, 
          item.tmdbId, 
          item.mediaType,
        );
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
