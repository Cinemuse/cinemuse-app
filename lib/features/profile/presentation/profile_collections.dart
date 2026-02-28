import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/collection_card.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/create_list_modal.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/edit_list_modal.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/list_details_modal.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/system_list_card.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ProfileCollections extends ConsumerWidget {
  const ProfileCollections({super.key});

  void _showCreateListModal(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => CreateListModal(
        onCreate: (name) async {
          final user = ref.read(authProvider).value;
          if (user == null) return;

          await ref.read(userListsProvider.notifier).createCustomList(name);
        },
      ),
    );
  }

  void _showEditListModal(BuildContext context, WidgetRef ref, UserList list) {
    showDialog(
      context: context,
      builder: (context) => EditListModal(
        list: list,
        onUpdate: (name, description) async {
          await ref.read(userListsProvider.notifier).updateList(
            list.id,
            name,
            description,
          );
        },
      ),
    );
  }

  void _showListDetails(BuildContext context, WidgetRef ref, UserList list) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => ListDetailsModal(
        list: list,
        onEdit: () {
          Navigator.pop(context); // Close details modal
          _showEditListModal(context, ref, list);
        },
        onDelete: () async {
          // Confirm delete
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppTheme.surface,
              title: Text(l10n.detailsDeleteListTitle, style: const TextStyle(color: Colors.white)),
              content: Text(l10n.detailsDeleteListConfirm(list.name), style: const TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.commonCancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.commonDelete, style: const TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
          );

          if (confirm == true) {
            final repo = ref.read(listsRepositoryProvider);
            await repo.deleteList(list.id);
            ref.invalidate(userListsProvider);
            if (context.mounted) Navigator.pop(context); // Close details modal
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final listsAsync = ref.watch(userListsProvider);

    return listsAsync.when(
      data: (lists) {
        // Filter lists by type
        final watchlist = lists.where((l) => l.type == ListType.watchlist).firstOrNull;
        final favorites = lists.where((l) => l.type == ListType.favorites).firstOrNull;
        final customLists = lists.where((l) => l.type == ListType.custom).toList();

        return SingleChildScrollView(
          padding: EdgeInsets.only(
            top: 24,
            left: AppTheme.getResponsiveHorizontalPadding(context),
            right: AppTheme.getResponsiveHorizontalPadding(context),
            bottom: AppTheme.getResponsiveHorizontalPadding(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. System Lists Top Row
              Row(
                children: [
                  if (watchlist != null)
                    Expanded(
                      child: SystemListCard(
                        list: watchlist,
                        onTap: () => _showListDetails(context, ref, watchlist),
                      ),
                    ),
                  if (watchlist != null && favorites != null)
                    const SizedBox(width: 24),
                  if (favorites != null)
                    Expanded(
                      child: SystemListCard(
                        list: favorites,
                        onTap: () => _showListDetails(context, ref, favorites),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 48),

              // 2. Collections Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.list, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            l10n.detailsCollectionsTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.detailsCollectionsDesc,
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => _showCreateListModal(context, ref),
                    icon: const Icon(LucideIcons.plus, size: 16, color: Color(0xFFC026D3)), // Matches the purple color in image
                    label: Text(
                      l10n.detailsNewCollection,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white10),
              const SizedBox(height: 24),

              // 3. Custom Lists Grid
              if (customLists.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Center(
                    child: Text(
                      l10n.detailsNoCollections,
                      style: TextStyle(color: Colors.white.withOpacity(0.3)),
                    ),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    childAspectRatio: 16 / 10,
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 24,
                  ),
                  itemCount: customLists.length,
                  itemBuilder: (context, index) {
                    final list = customLists[index];
                    return CollectionCard(
                      list: list,
                      onTap: () => _showListDetails(context, ref, list),
                    );
                  },
                ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Text('${l10n.commonError}: $err', style: const TextStyle(color: Colors.red)),
      ),
    );
  }
}

