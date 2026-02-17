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
                  AppTheme.getResponsiveHorizontalPadding(context), 
                  100, 
                  AppTheme.getResponsiveHorizontalPadding(context), 
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
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.searchNoResultsTitle, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(l10n.searchTryAdjusting, style: TextStyle(color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                );
              }

              final columns = _getColumnCount(context);
              final displayCount = (results.length ~/ columns) * columns;

              if (displayCount == 0 && results.isNotEmpty) {
                // If we have fewer items than a single row, just show what we have
                return SliverPadding(
                  padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.getResponsiveHorizontalPadding(context), 
                  vertical: 0
                ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 24,
                      crossAxisSpacing: 20,
                      childAspectRatio: 0.68,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildMediaCard(context, results[index], mediaType),
                      childCount: results.length,
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.getResponsiveHorizontalPadding(context), 
                  vertical: 0
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 24,
                    crossAxisSpacing: 20,
                    childAspectRatio: 0.68,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildMediaCard(context, results[index], mediaType),
                    childCount: displayCount,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
            ),
            error: (err, stack) => SliverFillRemaining(
              child: Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
            ),
          ),

          // Loading more indicator
          if (resultsAsync.isLoading && resultsAsync.hasValue && resultsAsync.value!.isNotEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
              ),
            ),
            
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  int _getColumnCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1600) return 8;
    if (width > 1200) return 6;
    if (width > 900) return 5;
    if (width > 600) return 4;
    if (width > 400) return 3;
    return 2;
  }

  Widget _buildMediaCard(BuildContext context, Map<String, dynamic> item, MediaType mediaType) {
    return MediaCard(
      title: item['title'] ?? item['name'] ?? '',
      posterPath: item['poster_path'] ?? item['profile_path'],
      releaseDate: item['release_date'] ?? item['first_air_date'] ?? '',
      rating: (item['vote_average'] as num?)?.toDouble(),
      onTap: () {
        if (mediaType != MediaType.person) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MediaDetailsScreen(
              mediaId: item['id'].toString(),
              mediaType: mediaType == MediaType.movie ? 'movie' : 'tv',
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isOpen ? Colors.white : AppTheme.secondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isOpen ? Colors.white : AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOpen ? Icons.tune : Icons.tune_outlined,
              size: 18,
              color: isOpen ? Colors.black : Colors.white70,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isOpen ? Colors.black : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 16,
              color: isOpen ? Colors.black : Colors.white70,
            ),
          ],
        ),
      ),
    );
  }
}
