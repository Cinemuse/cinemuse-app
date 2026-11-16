import 'package:flutter/material.dart';
import 'package:cinemuse_app/features/profile/application/title_marks_provider.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/shared/widgets/error_card.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/refresh_user_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'package:cinemuse_app/features/media/application/own_reviews_provider.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/profile/application/watch_history_view_provider.dart';
import 'package:cinemuse_app/features/profile/domain/watch_history_filter.dart';
import 'package:cinemuse_app/features/profile/domain/watch_history_view.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/watch_history_card.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/watch_history_card_rows.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/watch_history_filter_sheet.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/watch_history_header.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/watch_history_timeline.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/wreath.dart';

class WatchHistoryScreen extends ConsumerStatefulWidget {
  final MediaKind? initialType;

  const WatchHistoryScreen({super.key, this.initialType});

  @override
  ConsumerState<WatchHistoryScreen> createState() => _WatchHistoryScreenState();
}

class _WatchHistoryScreenState extends ConsumerState<WatchHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late WatchHistoryFilter _filter = WatchHistoryFilter(
    type: widget.initialType,
  );

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query != _filter.query) _setFilter(_filter.copyWith(query: query));
  }

  void _setFilter(WatchHistoryFilter filter) {
    setState(() => _filter = filter);
  }

  Future<void> _openFilterSheet() async {
    final result = await WatchHistoryFilterSheet.show(
      context: context,
      current: _filter,
    );
    if (result != null && mounted) _setFilter(result);
  }

  Future<void> _refresh() async {
    // A failed sync shows a snackbar; the screen keeps its data.
    await refreshUserData(context, ref);
    ref.invalidate(watchLogsProvider);
    ref.invalidate(allOwnReviewsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final viewAsync = ref.watch(watchHistoryViewProvider(_filter));
    // Read only while the Ratings view is chosen.
    final ratings = _filter.isRatings
        ? ref.watch(watchHistoryRatingsProvider(_filter))
        : null;

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: SafeArea(
        top: false,
        bottom: false,
        child: viewAsync.when(
          data: (view) => _buildContent(view, ratings),
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.accent),
          ),
          error: (err, _) => ErrorCard(
            error: ref.read(errorMapperProvider).map(err),
            onRetry: () => ref.invalidate(watchLogsProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    WatchHistoryView view,
    AsyncValue<List<RatingTier>>? ratings,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final isDesktop = MediaQuery.sizeOf(context).width >= Breakpoints.medium;
    final horizontalPadding = AppTheme.getResponsiveHorizontalPadding(context);
    final listPadding = EdgeInsets.fromLTRB(
      horizontalPadding,
      0,
      horizontalPadding,
      32,
    );

    return RefreshIndicator(
      color: AppTheme.accent,
      backgroundColor: AppTheme.surface,
      onRefresh: _refresh,
      child: CustomScrollView(
        cacheExtent: 600,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                isDesktop ? 16 : 12,
                horizontalPadding,
                isDesktop ? 20 : 12,
              ),
              child: WatchHistoryHeader(
                isDesktop: isDesktop,
                filter: _filter,
                counts: view.counts,
                ratedCount: ratings?.value?.fold<int>(
                  0,
                  (sum, tier) => sum + tier.titles.length,
                ),
                searchController: _searchController,
                searchFocusNode: _searchFocusNode,
                onFilterChanged: _setFilter,
                onOpenFilterSheet: _openFilterSheet,
              ),
            ),
          ),
          if (view.items.isEmpty)
            _EmptyHistory(message: l10n.watchHistoryEmpty)
          else if (ratings != null)
            ratings.when(
              data: (tiers) => tiers.isEmpty
                  ? _EmptyHistory(message: l10n.watchHistoryRatingsEmpty)
                  : SliverPadding(
                      padding: listPadding,
                      sliver: _RatingTiers(tiers: tiers),
                    ),
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.accent),
                ),
              ),
              // Where the posters go: the header stays, to change view.
              error: (err, _) => SliverPadding(
                padding: listPadding,
                sliver: SliverToBoxAdapter(
                  child: ErrorCard(
                    error: ref.read(errorMapperProvider).map(err),
                    onRetry: () => ref.invalidate(allOwnReviewsProvider),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: listPadding,
              sliver: _filter.isTimeline
                  ? WatchHistoryTimeline(
                      sections: view.sections,
                      granularity: _filter.granularity,
                    )
                  : _WatchHistoryGrid(items: view.items),
            ),
        ],
      ),
    );
  }
}

/// One card per title. A sliver; it builds only the cards on screen.
class _WatchHistoryGrid extends StatelessWidget {
  final List<WatchHistory> items;

  const _WatchHistoryGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: watchHistoryColumnCount(constraints.crossAxisExtent),
          childAspectRatio: watchHistoryCardAspectRatio,
          crossAxisSpacing: watchHistoryCardSpacing,
          mainAxisSpacing: watchHistoryCardSpacing,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => WatchHistoryCard(item: items[index]),
          childCount: items.length,
        ),
      ),
    );
  }
}

/// The titles under the wreath and number of their score. A sliver.
class _RatingTiers extends StatelessWidget {
  final List<RatingTier> tiers;

  const _RatingTiers({required this.tiers});

  @override
  Widget build(BuildContext context) {
    return WatchHistoryCardRows(
      sections: [
        for (final tier in tiers)
          WatchHistoryCardSection(
            header: _RatingTierHeader(score: tier.score),
            cardCount: tier.titles.length,
            cardBuilder: (index) => WatchHistoryCard(
              item: tier.titles[index],
              marksPlace: MarksPlace.ratings,
            ),
          ),
      ],
    );
  }
}

class _RatingTierHeader extends StatelessWidget {
  final int score;

  const _RatingTierHeader({required this.score});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wreath(score: score, size: 36),
        const SizedBox(width: 8),
        // The wreath already says the score to a screen reader.
        ExcludeSemantics(
          child: Text(
            '$score',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

/// A sliver.
class _EmptyHistory extends StatelessWidget {
  final String message;

  const _EmptyHistory({required this.message});

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_toggle_off_rounded,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
