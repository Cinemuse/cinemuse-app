import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';
import '../../../../core/presentation/theme/app_theme.dart';
import '../../application/explore_providers.dart';
import '../widgets/media_type_selector.dart';
import '../widgets/explore_result_card.dart';
import '../widgets/explore_filter_panel.dart';
import '../widgets/active_filters_list.dart';
import '../../../../shared/widgets/hover_scale.dart';
import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:cinemuse_app/shared/widgets/offline_placeholder.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _mediaTypeFocusNode = FocusNode(
    debugLabel: 'ExploreMediaType',
  );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(pageContentFocusActionsProvider.notifier)
            .update(
              (map) => {
                ...map,
                1: () {
                  if (_scrollController.hasClients &&
                      _scrollController.offset > 0) {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                    );
                  }
                  _mediaTypeFocusNode.requestFocus();
                },
              },
            );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _mediaTypeFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(exploreResultsProvider.notifier).fetchNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = ref.watch(connectivityProvider);
    final isOffline = connectivity.valueOrNull == ConnectivityResult.none;

    if (isOffline) {
      return OfflinePlaceholder(
        onRetry: () => ref.invalidate(connectivityProvider),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final mediaType = ref.watch(exploreMediaTypeProvider);
    final filters = ref.watch(exploreFiltersProvider);
    final resultsAsync = ref.watch(exploreResultsProvider);
    // A new page may still not fill the screen (big display): check after
    // layout whether the next one is needed, since no scroll event comes.
    ref.listen(exploreResultsProvider, (previous, next) {
      final items = next.valueOrNull?.items;
      if (items != null && !identical(items, previous?.valueOrNull?.items)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _onScroll();
        });
      }
    });

    final screenWidth = MediaQuery.of(context).size.width;
    const double maxContentWidth = 1600.0;
    final horizontalPadding = screenWidth > maxContentWidth
        ? (screenWidth - maxContentWidth) / 2 + 24
        : AppTheme.getResponsiveHorizontalPadding(context);

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: RefreshIndicator(
        color: AppTheme.accent,
        backgroundColor: AppTheme.secondary,
        onRefresh: () async {
          final user = ref.read(authProvider).value;
          if (user != null) {
            await Future.wait([
              ref
                  .read(watchHistoryRepositoryProvider)
                  .syncWatchHistory(user.id),
              ref.read(listsRepositoryProvider).syncUserLists(user.id),
            ]).catchError((_) => []);
          }

          ref.invalidate(exploreResultsProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: _scrollController,
          slivers: [
            // Header & Top Filter Bar
            SliverToBoxAdapter(
              child: RepaintBoundary(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    20,
                    horizontalPadding,
                    24,
                  ),
                  child: Column(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 700;

                          return SizedBox(
                            width: double.infinity,
                            child: isNarrow
                                ? Column(
                                    children: [
                                      MediaTypeSelector(
                                        selectedType: mediaType,
                                        movieFocusNode:
                                            mediaType == MediaType.movie
                                            ? _mediaTypeFocusNode
                                            : null,
                                        tvFocusNode: mediaType == MediaType.tv
                                            ? _mediaTypeFocusNode
                                            : null,
                                        personFocusNode:
                                            mediaType == MediaType.person
                                            ? _mediaTypeFocusNode
                                            : null,
                                        onTypeChanged: (type) {
                                          ref
                                              .read(
                                                exploreMediaTypeProvider
                                                    .notifier,
                                              )
                                              .select(type);
                                        },
                                      ),
                                      if (mediaType != MediaType.person) ...[
                                        const SizedBox(height: 16),
                                        _FilterToggleButton(
                                          onTap: () {
                                            AppBottomSheet.show(
                                              context: context,
                                              child: const AppBottomSheet(
                                                child: SingleChildScrollView(
                                                  child: Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 24.0,
                                                        ),
                                                    child: ExploreFilterPanel(),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                          label: l10n.searchFilterAction,
                                        ),
                                      ],
                                    ],
                                  )
                                : Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      MediaTypeSelector(
                                        selectedType: mediaType,
                                        movieFocusNode:
                                            mediaType == MediaType.movie
                                            ? _mediaTypeFocusNode
                                            : null,
                                        tvFocusNode: mediaType == MediaType.tv
                                            ? _mediaTypeFocusNode
                                            : null,
                                        personFocusNode:
                                            mediaType == MediaType.person
                                            ? _mediaTypeFocusNode
                                            : null,
                                        onTypeChanged: (type) {
                                          ref
                                              .read(
                                                exploreMediaTypeProvider
                                                    .notifier,
                                              )
                                              .select(type);
                                        },
                                      ),
                                      if (mediaType != MediaType.person)
                                        Positioned(
                                          right: 0,
                                          child: _FilterToggleButton(
                                            onTap: () {
                                              AppBottomSheet.show(
                                                context: context,
                                                child: const AppBottomSheet(
                                                  child: SingleChildScrollView(
                                                    child: Padding(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 24.0,
                                                          ),
                                                      child:
                                                          ExploreFilterPanel(),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                            label: l10n.searchFilterAction,
                                          ),
                                        ),
                                    ],
                                  ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      ActiveFiltersList(
                        filters: filters,
                        onChanged: (newFilters) {
                          ref.read(exploreFiltersProvider.notifier).state =
                              newFilters;
                        },
                        onClear: () {
                          ref.invalidate(exploreFiltersProvider);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Results Grid
            resultsAsync.when(
              data: (results) {
                final items = results.items;
                if (items.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.searchNoResultsTitle,
                              style: const TextStyle(
                                color: AppTheme.textWhite,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.searchTryAdjusting,
                              style: const TextStyle(color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 0,
                  ),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      const double itemWidth = 200;
                      const double spacing = 12;

                      // crossAxisExtent is the width available for the grid
                      final crossAxisCount =
                          ((constraints.crossAxisExtent + spacing) /
                                  (itemWidth + spacing))
                              .floor()
                              .clamp(2, 12);

                      // Only full rows while a next page can fill the last
                      // one; the last page shows everything.
                      final fullRows =
                          (items.length ~/ crossAxisCount) * crossAxisCount;
                      final displayCount = !results.hasMore || fullRows == 0
                          ? items.length
                          : fullRows;

                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: spacing,
                          childAspectRatio: 0.56,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => ExploreResultCard(
                            media: items[index],
                            type: mediaType,
                          ),
                          childCount: displayCount,
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    child: const CircularProgressIndicator(
                      color: AppTheme.accent,
                    ),
                  ),
                ),
              ),
              error: (err, stack) => SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ref.watch(errorMapperProvider).map(err).message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          autofocus: true,
                          onPressed: () =>
                              ref.invalidate(exploreResultsProvider),
                          child: Text(l10n.commonRetry),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Loading more indicator
            if (resultsAsync.valueOrNull?.isLoadingMore ?? false)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    24,
                    horizontalPadding,
                    24,
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: AppTheme.accent),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

class _FilterToggleButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const _FilterToggleButton({required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    return HoverScale(
      onTap: onTap,
      scale: 1.05,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.secondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.tune_outlined,
              size: 18,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
