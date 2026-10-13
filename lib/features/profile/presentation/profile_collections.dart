import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/collection_card.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/create_list_sheet.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/list_delete_with_undo.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/list_details_sheet.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/system_list_card.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/shared/widgets/error_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ProfileCollections extends ConsumerWidget {
  const ProfileCollections({super.key});

  void _showCreateListModal(BuildContext context, WidgetRef ref) {
    CreateListSheet.show(
      context,
      onCreate: (name) async {
        final user = ref.read(authProvider).value;
        if (user == null) return;

        await ref.read(userListsProvider.notifier).createCustomList(name);
      },
    );
  }

  void _showListDetails(BuildContext context, WidgetRef ref, UserList list) {
    ListDetailsSheet.show(
      context,
      list: list,
      onUpdate: list.isSystemList
          ? null
          : (name, description) async {
              await ref
                  .read(userListsProvider.notifier)
                  .updateList(list.id, name, description);
            },
      onDelete: () => deleteListWithUndo(context, ref, list),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final listsAsync = ref.watch(userListsProvider);
    final droppedListAsync = ref.watch(droppedListProvider);

    return listsAsync.when(
      data: (lists) {
        // Filter lists by type
        final watchlist = lists
            .where((l) => l.type == ListType.watchlist)
            .firstOrNull;
        final favorites = lists
            .where((l) => l.type == ListType.favorites)
            .firstOrNull;
        final customLists = lists
            .where((l) => l.type == ListType.custom)
            .toList();

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
              Builder(
                builder: (context) {
                  final isMobile = Breakpoints.isCompact(context);

                  final watchlistCard = watchlist != null
                      ? SystemListCard(
                          list: watchlist,
                          onTap: () =>
                              _showListDetails(context, ref, watchlist),
                        )
                      : null;

                  final favoritesCard = favorites != null
                      ? SystemListCard(
                          list: favorites,
                          onTap: () =>
                              _showListDetails(context, ref, favorites),
                        )
                      : null;

                  final droppedList = droppedListAsync.valueOrNull;
                  final droppedCard = droppedList != null
                      ? SystemListCard(
                          list: droppedList,
                          onTap: () =>
                              _showListDetails(context, ref, droppedList),
                        )
                      : null;

                  if (isMobile) {
                    return Column(
                      children: [
                        if (watchlistCard != null) watchlistCard,
                        if (watchlistCard != null && favoritesCard != null)
                          const SizedBox(height: 16),
                        if (favoritesCard != null) favoritesCard,
                        if ((watchlistCard != null || favoritesCard != null) &&
                            droppedCard != null)
                          const SizedBox(height: 16),
                        if (droppedCard != null) droppedCard,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      if (watchlistCard != null)
                        Expanded(flex: 4, child: watchlistCard),
                      if (watchlistCard != null && favoritesCard != null)
                        const SizedBox(width: 24),
                      if (favoritesCard != null)
                        Expanded(flex: 4, child: favoritesCard),
                      if ((watchlistCard != null || favoritesCard != null) &&
                          droppedCard != null)
                        const SizedBox(width: 24),
                      if (droppedCard != null)
                        Expanded(flex: 3, child: droppedCard),
                    ],
                  );
                },
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
                          const Icon(
                            LucideIcons.list,
                            color: Colors.white,
                            size: 20,
                          ),
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
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => _showCreateListModal(context, ref),
                    icon: const Icon(
                      LucideIcons.plus,
                      size: 16,
                      color: AppTheme.accentHover,
                    ),
                    label: Text(
                      l10n.detailsNewCollection,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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
                    color: AppTheme.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      l10n.detailsNoCollections,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
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
      error: (err, stack) {
        final error = ref.read(errorMapperProvider).map(err);
        return ErrorCard(
          message: error.message,
          hint: error.hint,
          type: error.type,
          onRetry: () => ref.invalidate(userListsProvider),
        );
      },
    );
  }
}
