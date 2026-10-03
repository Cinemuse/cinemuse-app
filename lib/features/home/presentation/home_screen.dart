import 'package:cinemuse_app/features/home/application/home_providers.dart';
import 'package:cinemuse_app/features/home/presentation/widgets/continue_watching_row.dart';
import 'package:cinemuse_app/features/home/presentation/widgets/sport_schedule_row.dart';
import 'package:cinemuse_app/features/home/presentation/widgets/hero_section.dart';
import 'package:cinemuse_app/features/home/presentation/widgets/media_row.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/shared/widgets/error_card.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/offline_banner.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/list_details_sheet.dart';
import 'package:cinemuse_app/features/navigation/nav_providers.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _heroFocusNode = FocusNode(debugLabel: 'HomeHero');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(pageContentFocusActionsProvider.notifier).update(
          (map) => {
            ...map,
            0: () {
              if (_scrollController.hasClients && _scrollController.offset > 0) {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                );
              }
              _heroFocusNode.requestFocus();
            },
          },
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _heroFocusNode.dispose();
    super.dispose();
  }
  void _showListDetails(BuildContext context, UserList list) {
    final isSystemList =
        list.type == ListType.watchlist || list.type == ListType.favorites;

    ListDetailsSheet.show(
      context,
      list: list,
      onUpdate: isSystemList
          ? null
          : (name, description) async {
              await ref
                  .read(userListsProvider.notifier)
                  .updateList(list.id, name, description);
            },
      onDelete: () => _deleteListWithUndo(context, list),
    );
  }

  Future<void> _deleteListWithUndo(BuildContext context, UserList list) async {
    final l10n = AppLocalizations.of(context)!;
    // Optimistic delete
    // The modal is closed by ListDetailsSheet itself to avoid context issues
    final notifier = ref.read(userListsProvider.notifier);
    notifier.optimisticRemove(list.id);

    final reason = await AppSnackBar.show(
      context,
      message: l10n.detailsListDeleted(list.name),
      actionLabel: l10n.commonUndo,
      showTimer: true,
      onAction: () {}, // Action just closes the snackbar with 'action' reason
    ).closed;

    if (reason != SnackBarClosedReason.action) {
      final repo = ref.read(listsRepositoryProvider);
      await repo.deleteList(list.id);
    } else {
      // User undid the deletion, restore the UI state
      ref.invalidate(userListsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final trendingAsync = ref.watch(trendingProvider);
    final popularMoviesAsync = ref.watch(popularMoviesProvider);
    final popularSeriesAsync = ref.watch(popularSeriesProvider);
    final connectivity = ref.watch(connectivityProvider);
    final userListsAsync = ref.watch(userListsProvider);
    final pinnedListIds = ref.watch(pinnedListIdsProvider);

    final isOffline = connectivity.valueOrNull == ConnectivityResult.none;
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        color: theme.colorScheme.primary,
        backgroundColor: theme.colorScheme.surfaceContainer,
        onRefresh: () async {
          final user = ref.read(authProvider).value;
          if (user != null) {
            await Future.wait([
              ref.read(watchHistoryRepositoryProvider).syncWatchHistory(user.id),
              ref.read(listsRepositoryProvider).syncUserLists(user.id),
            ]).catchError((_) => []);
          }

          ref.invalidate(trendingProvider);
          ref.invalidate(popularMoviesProvider);
          ref.invalidate(popularSeriesProvider);
          ref.invalidate(userListsProvider);
          // Small delay to allow animations to complete smoothly
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          child: Column(
          children: [
            if (!isOffline) ...[
              // 1. Hero Section (Top 5 Trending Carousel)
              RepaintBoundary(
                child: trendingAsync.when(
                  data: (data) => HeroSection(
                    items: data.take(5).toList(),
                    focusNode: _heroFocusNode,
                  ),
                  loading: () => SizedBox(
                    height: HeroSection.getHeroHeight(context),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, stack) {
                    final mapped = ref.read(errorMapperProvider).map(err);
                    return SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: ErrorCard(
                            message: mapped.message,
                            hint: mapped.hint,
                            type: mapped.type,
                            onRetry: () => ref.refresh(trendingProvider),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              // Offline Spacer to account for missing Hero height
              const SizedBox(height: 40),
              OfflineBanner(
                onRetry: () => ref.invalidate(connectivityProvider),
              ),
            ],

            // 2. Content
            Transform.translate(
              offset: Offset(
                0,
                AppTheme.getHeroContentOverlap(
                  isMobile: isMobile,
                  isOffline: isOffline,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Continue Watching
                  const RepaintBoundary(
                    child: ContinueWatchingRow(),
                  ),

                  // Sports Schedule
                  const RepaintBoundary(
                    child: SportScheduleRow(),
                  ),

                  // Pinned Lists
                  userListsAsync.when(
                    data: (lists) {
                      final pinnedLists = lists
                          .where((list) => pinnedListIds.contains(list.id))
                          .toList();
                      if (pinnedLists.isEmpty) return const SizedBox.shrink();

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 10),
                          ...pinnedLists.map((list) {
                            final mediaItems = list.items.map((item) => item.toMediaItem()).toList();

                            final String title;
                            if (list.type == ListType.watchlist) {
                              title = l10n.listWatchLater;
                            } else if (list.type == ListType.favorites) {
                              title = l10n.listFavorites;
                            } else {
                              title = list.name;
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: RepaintBoundary(
                                child: MediaRow(
                                  title: title,
                                  asyncData: AsyncValue.data(mediaItems),
                                  onHeaderTap: () => _showListDetails(context, list),
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (err, stack) => const SizedBox.shrink(),
                  ),

                  // Pinned Collections
                  ...pinnedListIds
                      .where((id) => id.startsWith('collection_'))
                      .map((id) => _PinnedCollectionRow(collectionId: id)),

                  if (!isOffline) ...[
                    const SizedBox(height: 10),
                    // Trending List
                    RepaintBoundary(
                      child: MediaRow(
                        title: l10n.homeTrendingNow,
                        asyncData: trendingAsync,
                        skipFirst: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Popular Movies
                    RepaintBoundary(
                      child: MediaRow(
                        title: l10n.homePopularMovies,
                        asyncData: popularMoviesAsync,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Popular Series
                    RepaintBoundary(
                      child: MediaRow(
                        title: l10n.homePopularSeries,
                        asyncData: popularSeriesAsync,
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _PinnedCollectionRow extends ConsumerWidget {
  final String collectionId;
  const _PinnedCollectionRow({required this.collectionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = int.tryParse(collectionId.replaceFirst('collection_', '')) ?? 0;
    if (id == 0) return const SizedBox.shrink();

    final asyncData = ref.watch(collectionModelProvider(id));

    return asyncData.when(
      data: (collection) {
        if (collection == null || collection.parts.isEmpty) {
          return const SizedBox.shrink();
        }
        final l10n = AppLocalizations.of(context)!;
        final title = collection.name.isNotEmpty
            ? collection.name
            : l10n.collectionTitleFallback;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: RepaintBoundary(
            child: MediaRow(
              title: title,
              asyncData: AsyncValue.data(collection.parts),
              onHeaderTap: () {
                final listItems = collection.parts
                    .map((mediaItem) => UserListItem(
                          listId: collectionId,
                          addedAt: DateTime.now(),
                          tmdbId: mediaItem.tmdbId,
                          mediaType: mediaItem.mediaType,
                          media: mediaItem,
                          meta: const {},
                        ))
                    .toList();
                final userList = UserList(
                  id: collectionId,
                  name: title,
                  description: collection.overview,
                  type: ListType.custom,
                  items: listItems,
                  createdAt: DateTime.now(),
                  userId: 'system',
                );
                ListDetailsSheet.show(context, list: userList);
              },
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
