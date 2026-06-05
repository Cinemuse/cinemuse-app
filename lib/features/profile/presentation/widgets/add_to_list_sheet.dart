import 'package:cinemuse_app/core/constants/app_constants.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_bottom_sheet.dart';
import 'package:cinemuse_app/shared/widgets/hover_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AddToListSheet extends ConsumerStatefulWidget {
  final MediaItem media;

  const AddToListSheet({super.key, required this.media});

  static Future<void> show(BuildContext context, MediaItem media) {
    return AppBottomSheet.show(
      context: context,
      constraints: const BoxConstraints(maxWidth: 500),
      child: AddToListSheet(media: media),
    );
  }

  @override
  ConsumerState<AddToListSheet> createState() => _AddToListSheetState();
}

class _AddToListSheetState extends ConsumerState<AddToListSheet> {
  bool _isCreatingList = false;
  final TextEditingController _listNameController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _listNameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleCreateList() async {
    final name = _listNameController.text.trim();
    if (name.isNotEmpty) {
      await ref.read(userListsProvider.notifier).createCustomList(name);
      setState(() {
        _isCreatingList = false;
        _listNameController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final listsAsync = ref.watch(userListsProvider);

    return AppBottomSheet(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 8,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.detailsAddToList,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            listsAsync.when(
              data: (lists) {
                final customLists = lists
                    .where((l) => l.type == ListType.custom)
                    .toList();

                if (customLists.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            LucideIcons.list,
                            color: Colors.white.withValues(alpha: 0.2),
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.detailsNoCustomLists,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: customLists.length,
                    itemBuilder: (context, index) {
                      final list = customLists[index];
                      final isInList = list.items.any(
                        (i) =>
                            i.tmdbId == widget.media.tmdbId &&
                            i.mediaType == widget.media.mediaType,
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: HoverScale(
                          scale: 1.02,
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              hoverColor: Colors.white.withValues(alpha: 0.1),
                              splashColor: Colors.white.withValues(alpha: 0.05),
                              onTap: () async {
                                if (isInList) {
                                  await ref
                                      .read(listsRepositoryProvider)
                                      .removeItemFromList(
                                        listId: list.id,
                                        tmdbId: widget.media.tmdbId,
                                        mediaType: widget.media.mediaType.name,
                                      );
                                  ref.invalidate(userListsProvider);
                                } else {
                                  await ref
                                      .read(userListsProvider.notifier)
                                      .addItemToCustomList(
                                        list.id,
                                        widget.media,
                                      );
                                }
                              },
                              leading: Icon(
                                isInList
                                    ? LucideIcons.checkCircle2
                                    : LucideIcons.circle,
                                color: isInList
                                    ? AppTheme.accent
                                    : Colors.white24,
                                size: 20,
                              ),
                              title: Text(
                                list.name,
                                style: TextStyle(
                                  color: isInList
                                      ? Colors.white
                                      : Colors.white70,
                                  fontWeight: isInList
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              trailing: Text(
                                '${list.items.length}',
                                style: const TextStyle(
                                  color: Colors.white24,
                                  fontSize: 12,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              ),
              error: (err, _) => Text(
                'Error: $err',
                style: const TextStyle(color: Colors.red),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),

            // Inline Create List Area
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1.0,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: _isCreatingList
                  ? _buildCreateListInput(l10n)
                  : _buildCreateListButton(l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateListButton(AppLocalizations l10n) {
    return Container(
      key: const ValueKey('create_btn'),
      margin: const EdgeInsets.only(bottom: 4),
      child: HoverScale(
        scale: 1.02,
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            hoverColor: Colors.white.withValues(alpha: 0.1),
            splashColor: Colors.white.withValues(alpha: 0.05),
            onTap: () {
              setState(() {
                _isCreatingList = true;
              });
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) _focusNode.requestFocus();
              });
            },
            leading: const Icon(
              LucideIcons.plus,
              color: Colors.white,
              size: 20,
            ),
            title: Text(
              l10n.detailsCreateNewList,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateListInput(AppLocalizations l10n) {
    return Container(
      key: const ValueKey('create_input'),
      margin: const EdgeInsets.only(bottom: 4),
      child: TextField(
        controller: _listNameController,
        focusNode: _focusNode,
        maxLength: AppConstants.maxListNameLength,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: l10n.detailsCreateNewList,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.accent),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          counterStyle: const TextStyle(color: Colors.white38),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  LucideIcons.x,
                  size: 20,
                  color: Colors.white54,
                ),
                onPressed: () {
                  setState(() {
                    _isCreatingList = false;
                    _listNameController.clear();
                  });
                },
                tooltip: 'Cancel',
                splashRadius: 20,
              ),
              IconButton(
                icon: const Icon(
                  LucideIcons.check,
                  size: 20,
                  color: AppTheme.accent,
                ),
                onPressed: _handleCreateList,
                tooltip: 'Save',
                splashRadius: 20,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
        onSubmitted: (_) => _handleCreateList(),
      ),
    );
  }
}
