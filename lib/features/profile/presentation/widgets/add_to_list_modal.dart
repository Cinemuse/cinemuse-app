import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/create_list_modal.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AddToListModal extends ConsumerWidget {
  final MediaItem media;

  const AddToListModal({
    super.key,
    required this.media,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final listsAsync = ref.watch(userListsProvider);

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Colors.white10),
      ),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(
          maxWidth: 400,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.detailsAddToList,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x, color: Colors.white54, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            listsAsync.when(
              data: (lists) {
                final customLists = lists.where((l) => l.type == ListType.custom).toList();
                
                if (customLists.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(LucideIcons.list, color: Colors.white.withOpacity(0.2), size: 48),
                          const SizedBox(height: 16),
                          Text(
                            l10n.detailsNoCustomLists,
                            style: TextStyle(color: Colors.white.withOpacity(0.5)),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: customLists.length,
                    itemBuilder: (context, index) {
                      final list = customLists[index];
                      final isInList = list.items.any((i) => 
                        i.tmdbId == media.tmdbId && i.mediaType == media.mediaType
                      );

                      return ListTile(
                        onTap: () async {
                          if (isInList) {
                            await ref.read(listsRepositoryProvider).removeItemFromList(
                              listId: list.id,
                              tmdbId: media.tmdbId,
                              mediaType: media.mediaType.name,
                            );
                            ref.invalidate(userListsProvider);
                          } else {
                            await ref.read(userListsProvider.notifier).addItemToCustomList(
                              list.id,
                              media,
                            );
                          }
                        },
                        leading: Icon(
                          isInList ? LucideIcons.checkCircle2 : LucideIcons.circle,
                          color: isInList ? AppTheme.accent : Colors.white24,
                          size: 20,
                        ),
                        title: Text(
                          list.name,
                          style: TextStyle(
                            color: isInList ? Colors.white : Colors.white70,
                            fontWeight: isInList ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: Text(
                          '${list.items.length}',
                          style: const TextStyle(color: Colors.white24, fontSize: 12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error: $err', style: const TextStyle(color: Colors.red)),
            ),

            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),

            // Create New List Button
            TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => CreateListModal(
                    onCreate: (name) async {
                      await ref.read(userListsProvider.notifier).createCustomList(name);
                    },
                  ),
                );
              },
              icon: const Icon(LucideIcons.plus, size: 18, color: AppTheme.accent),
              label: Text(
                l10n.detailsCreateNewList,
                style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
