import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';
import '../../../../core/presentation/theme/app_theme.dart';
import '../../application/explore_providers.dart';
import '../widgets/explore_header.dart';
import '../widgets/explore_result_card.dart';
import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:cinemuse_app/shared/widgets/error_card.dart';
import 'package:cinemuse_app/shared/widgets/offline_placeholder.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';

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
                NavTab.explore: () {
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

    final screenWidth = MediaQuery.sizeOf(context).width;
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
          ref.invalidate(exploreResultsProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: RepaintBoundary(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    20,
                    horizontalPadding,
                    24,
                  ),
                  child: ExploreHeader(
                    selectedTypeFocusNode: _mediaTypeFocusNode,
                  ),
                ),
              ),
            ),
            resultsAsync.when(
              data: (results) => results.items.isEmpty
                  ? _CenteredFill(
                      horizontalPadding: horizontalPadding,
                      child: const _NoResults(),
                    )
                  : SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      sliver: _ResultsGrid(results: results),
                    ),
              loading: () => _CenteredFill(
                horizontalPadding: horizontalPadding,
                child: const CircularProgressIndicator(color: AppTheme.accent),
              ),
              error: (err, stack) => _CenteredFill(
                horizontalPadding: horizontalPadding,
                child: ErrorCard(
                  error: ref.watch(errorMapperProvider).map(err),
                  onRetry: () => ref.invalidate(exploreResultsProvider),
                  autofocus: true,
                ),
              ),
            ),
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

/// Fills the space under the header with [child] in the middle.
class _CenteredFill extends StatelessWidget {
  final double horizontalPadding;
  final Widget child;

  const _CenteredFill({required this.horizontalPadding, required this.child});

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: child,
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
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
    );
  }
}

class _ResultsGrid extends ConsumerWidget {
  final ExploreResults results;

  const _ResultsGrid({required this.results});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ref.watch(exploreMediaTypeProvider);
    final items = results.items;

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        const double itemWidth = 200;
        const double spacing = 12;

        // crossAxisExtent is the width available for the grid
        final crossAxisCount =
            ((constraints.crossAxisExtent + spacing) / (itemWidth + spacing))
                .floor()
                .clamp(2, 12);

        // Only full rows while a next page can fill the last one; the last
        // page shows everything.
        final fullRows = (items.length ~/ crossAxisCount) * crossAxisCount;
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
            (context, index) =>
                ExploreResultCard(media: items[index], type: type),
            childCount: displayCount,
          ),
        );
      },
    );
  }
}
