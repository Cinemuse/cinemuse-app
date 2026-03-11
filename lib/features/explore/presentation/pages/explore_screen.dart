import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import '../../../../core/presentation/theme/app_theme.dart';
import '../../../../shared/widgets/media_card.dart';
import '../../application/explore_providers.dart';
import '../widgets/media_type_selector.dart';
import '../widgets/explore_filter_panel.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import '../widgets/active_filters_list.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import '../../../../shared/widgets/hover_scale.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(exploreResultsProvider.notifier).fetchNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mediaType = ref.watch(exploreMediaTypeProvider);
    final filters = ref.watch(exploreFiltersProvider);
    final resultsAsync = ref.watch(exploreResultsProvider);

    final screenWidth = MediaQuery.of(context).size.width;
    const double maxContentWidth = 1600.0;
    final horizontalPadding = screenWidth > maxContentWidth 
        ? (screenWidth - maxContentWidth) / 2 + 24
        : AppTheme.getResponsiveHorizontalPadding(context);

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: CustomScrollView(
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
                  24
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
                                  onTypeChanged: (type) {
                                    ref.read(exploreMediaTypeProvider.notifier).state = type;
                                    ref.read(exploreResultsProvider.notifier).reset();
                                  },
                                ),
                                if (mediaType != MediaType.person) ...[
                                  const SizedBox(height: 16),
                                  _FilterToggleButton(
                                    isOpen: _showFilters,
                                    onTap: () => setState(() => _showFilters = !_showFilters),
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
                                  onTypeChanged: (type) {
                                    ref.read(exploreMediaTypeProvider.notifier).state = type;
                                    ref.read(exploreResultsProvider.notifier).reset();
                                  },
                                ),
                                if (mediaType != MediaType.person)
                                  Positioned(
                                    right: 0,
                                    child: _FilterToggleButton(
                                      isOpen: _showFilters,
                                      onTap: () => setState(() => _showFilters = !_showFilters),
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
                      ref.read(exploreFiltersProvider.notifier).state = newFilters;
                      ref.read(exploreResultsProvider.notifier).reset();
                    },
                    onClear: () {
                      ref.invalidate(exploreFiltersProvider);
                      ref.read(exploreResultsProvider.notifier).reset();
                    },
                  ),
                  ExploreFilterPanel(
                    show: _showFilters,
                    filters: filters,
                    onChanged: (newFilters) {
                      ref.read(exploreFiltersProvider.notifier).state = newFilters;
                      ref.read(exploreResultsProvider.notifier).reset();
                    },
                    onClear: () {
                      ref.invalidate(exploreFiltersProvider);
                      ref.read(exploreResultsProvider.notifier).reset();
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
              if (results.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l10n.searchNoResultsTitle, style: const TextStyle(color: AppTheme.textWhite, fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(l10n.searchTryAdjusting, style: const TextStyle(color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding, 
                  vertical: 0
                ),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    const double itemWidth = 200;
                    const double spacing = 12;
                    
                    // crossAxisExtent is the width available for the grid
                    final crossAxisCount = ((constraints.crossAxisExtent + spacing) / (itemWidth + spacing)).floor().clamp(2, 12);
                    
                    // "Full Row" logic: only show full rows
                    final displayCount = (results.length ~/ crossAxisCount) * crossAxisCount;

                    if (displayCount == 0 && results.isNotEmpty) {
                       // If we can't even fill one row, show what we have so it's not empty
                       return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: spacing,
                          childAspectRatio: 0.68,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildMediaCard(context, results[index], mediaType),
                          childCount: results.length,
                        ),
                      );
                    }

                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: spacing,
                        childAspectRatio: 0.68,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildMediaCard(context, results[index], mediaType),
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
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: const CircularProgressIndicator(color: AppTheme.accent),
                ),
              ),
            ),
            error: (err, stack) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Text('${l10n.commonError}: $err', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              ),
            ),
          ),

          // Loading more indicator
          if (resultsAsync.isLoading && resultsAsync.hasValue && resultsAsync.value!.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 24),
                child: const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
              ),
            ),
            
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }


  Widget _buildMediaCard(BuildContext context, Map<String, dynamic> media, MediaType mediaTypeEnum) {
    final title = media['title'] ?? media['name'] ?? AppLocalizations.of(context)!.commonUnknown;
    final posterPath = media['poster_path'] ?? media['profile_path'];
    final releaseDate = media['release_date'] ?? media['first_air_date'];
    final rating = (media['vote_average'] as num?)?.toDouble();
    final tmdbId = media['id'] as int;
    final mediaTypeString = mediaTypeEnum == MediaType.movie ? 'movie' : 'tv';
    final kind = mediaTypeEnum == MediaType.movie ? MediaKind.movie : MediaKind.tv;

    return MediaCard(
      title: title,
      posterPath: posterPath,
      releaseDate: releaseDate,
      rating: rating,
      tmdbId: tmdbId,
      mediaType: kind,
      showWatchlistButton: true,
      onTap: () {
        if (mediaTypeEnum != MediaType.person) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MediaDetailsScreen(
              mediaId: media['id'].toString(),
              mediaType: mediaTypeString,
            ),
          ));
        }
      },
    );
  }
}

class _FilterToggleButton extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onTap;
  final String label;

  const _FilterToggleButton({
    required this.isOpen,
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return HoverScale(
      onTap: onTap,
      scale: 1.05,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isOpen ? AppTheme.textWhite : AppTheme.secondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOpen ? AppTheme.textWhite : AppTheme.border,
          ),
          boxShadow: isOpen ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOpen ? Icons.tune : Icons.tune_outlined,
              size: 18,
              color: isOpen ? Colors.black : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isOpen ? Colors.black : AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 16,
              color: isOpen ? Colors.black : AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
