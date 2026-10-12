import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:cinemuse_app/shared/widgets/app_back_button.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/watch_history_filter_sheet.dart';

enum HistoryViewMode { grid, timeline }

enum TimelineGranularity { daily, monthly, yearly }

enum HistorySortOption { recentlyWatched, releaseDate, rating, title }

class WatchHistoryScreen extends ConsumerStatefulWidget {
  final MediaKind? initialType;

  const WatchHistoryScreen({super.key, this.initialType});

  @override
  ConsumerState<WatchHistoryScreen> createState() => _WatchHistoryScreenState();
}

class _WatchHistoryScreenState extends ConsumerState<WatchHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  MediaKind? _selectedType;
  WatchStatus? _selectedStatus;
  String _searchQuery = '';
  HistoryViewMode _viewMode = HistoryViewMode.grid;
  TimelineGranularity _granularity = TimelineGranularity.daily;
  HistorySortOption _sortOption = HistorySortOption.recentlyWatched;

  // Progressive batch loading state for high-performance rendering
  int _visibleSectionCount = 30;
  int _visibleGridCount = 60;

  // Cache for filtered/sorted items
  List<WatchHistory>? _lastRawList;
  MediaKind? _lastType;
  WatchStatus? _lastStatus;
  String _lastQuery = '';
  HistoryViewMode? _lastViewMode;
  HistorySortOption? _lastSortOption;
  String? _lastLanguage;
  List<WatchHistory> _cachedFilteredList = const [];

  // Cache for timeline grouped sections
  List<WatchHistory>? _lastFilteredForTimeline;
  TimelineGranularity? _lastGranularity;
  String? _lastLanguageForTimeline;
  List<_TimelineSection> _cachedTimelineSections = const [];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.removeListener(_onFocusChanged);
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() {});
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query != _searchQuery) {
      setState(() {
        _searchQuery = query;
        _resetPagination();
      });
    }
  }

  void _resetPagination() {
    _visibleSectionCount = 30;
    _visibleGridCount = 60;
  }

  void _loadMoreIfNeeded(int totalItems) {
    if (_viewMode == HistoryViewMode.grid) {
      if (_visibleGridCount < totalItems) {
        setState(() {
          _visibleGridCount = (_visibleGridCount + 60).clamp(0, totalItems);
        });
      }
    } else {
      if (_visibleSectionCount < _cachedTimelineSections.length) {
        setState(() {
          _visibleSectionCount = (_visibleSectionCount + 30).clamp(
            0,
            _cachedTimelineSections.length,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appLanguage = ref.watch(settingsProvider).appLanguage;
    final historyAsync = ref.watch(watchLogsProvider);
    final localHistoryAsync = ref.watch(watchHistoryStreamProvider);
    final horizontalPadding = AppTheme.getResponsiveHorizontalPadding(context);

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: SafeArea(
        top: false,
        bottom: false,
        child: historyAsync.when(
          data: (historyList) {
            final localList = localHistoryAsync.valueOrNull ?? const [];
            final joined = _joinLogsWithLocalHistory(historyList, localList);
            final filtered = _filterAndSortItems(joined, appLanguage);
            return _buildContent(
              context,
              l10n,
              appLanguage,
              filtered,
              joined,
              horizontalPadding,
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.accent),
          ),
          error: (err, _) {
            final localList = localHistoryAsync.valueOrNull;
            if (localList != null && localList.isNotEmpty) {
              final filtered = _filterAndSortItems(localList, appLanguage);
              return _buildContent(
                context,
                l10n,
                appLanguage,
                filtered,
                localList,
                horizontalPadding,
              );
            }
            return Center(
              child: Text(
                '${l10n.commonError}: $err',
                style: const TextStyle(color: Colors.white70),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Locally joins remote chronological watch logs with local Drift watch history,
  /// ensuring real-time status (watching, dropped, completed) and in-progress states are reflected.
  List<WatchHistory> _joinLogsWithLocalHistory(
    List<WatchHistory> logs,
    List<WatchHistory> localList,
  ) {
    if (localList.isEmpty) return logs;

    final localMap = <String, WatchHistory>{};
    for (final item in localList) {
      localMap[item.titleKey] = item;
    }

    final joined = <WatchHistory>[];
    final loggedMediaKeys = <String>{};

    for (final log in logs) {
      final key = log.titleKey;
      loggedMediaKeys.add(key);
      final local = localMap[key];

      if (local != null) {
        joined.add(
          WatchHistory(
            userId: log.userId,
            tmdbId: log.tmdbId,
            mediaType: log.mediaType,
            status: local.status ?? log.status ?? WatchStatus.completed,
            progressSeconds: log.progressSeconds > 0
                ? log.progressSeconds
                : local.progressSeconds,
            totalDuration: log.totalDuration ?? local.totalDuration,
            watchCount: log.watchCount,
            lastWatchedAt: log.lastWatchedAt,
            season: log.season ?? local.season,
            episode: log.episode ?? local.episode,
            media: log.media ?? local.media,
          ),
        );
      } else {
        joined.add(log);
      }
    }

    // Append any local in-progress or dropped items that have no completed watch_logs entries
    for (final local in localList) {
      final key = local.titleKey;
      if (!loggedMediaKeys.contains(key)) {
        joined.add(local);
      } else if (local.status == WatchStatus.watching &&
          local.progressSeconds > 0) {
        final hasActiveEntry = joined.any(
          (j) =>
              j.titleKey == local.titleKey &&
              j.season == local.season &&
              j.episode == local.episode &&
              j.status == WatchStatus.watching,
        );
        if (!hasActiveEntry) {
          joined.add(local);
        }
      }
    }

    return joined;
  }

  Widget _buildContent(
    BuildContext context,
    AppLocalizations l10n,
    String appLanguage,
    List<WatchHistory> items,
    List<WatchHistory> allHistory,
    double horizontalPadding,
  ) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 850;

    // 1. Overall unique items across full history. The header counts only
    // what this screen loaded, never the server stats (REV-269).
    final totalUniqueMap = <String, WatchHistory>{};
    for (final item in allHistory.where((h) => h.media != null)) {
      final existing = totalUniqueMap[item.titleKey];
      if (existing == null ||
          item.lastWatchedAt.isAfter(existing.lastWatchedAt)) {
        totalUniqueMap[item.titleKey] = item;
      }
    }
    final totalMovies = totalUniqueMap.values
        .where((h) => h.mediaType == MediaKind.movie)
        .length;
    final totalSeries = totalUniqueMap.values
        .where((h) => h.mediaType == MediaKind.tv)
        .length;
    final totalCount = totalMovies + totalSeries;

    // 2. Filtered unique titles
    final filteredUniqueMap = <String, WatchHistory>{};
    for (final item in items.where((h) => h.media != null)) {
      filteredUniqueMap[item.titleKey] = item;
    }
    final filteredItemsList = filteredUniqueMap.values.toList();
    final filteredMovies = filteredItemsList
        .where((h) => h.mediaType == MediaKind.movie)
        .length;
    final filteredSeries = filteredItemsList
        .where((h) => h.mediaType == MediaKind.tv)
        .length;
    final filteredTotalTitles = filteredMovies + filteredSeries;

    // 3. For series: calculate distinct seasons and total episode logs in the filtered scope
    final seasonsSet = <String>{};
    int episodesCount = 0;
    for (final item in items.where((h) => h.mediaType == MediaKind.tv)) {
      if (item.season != null && item.season! > 0) {
        seasonsSet.add('${item.tmdbId}-${item.season}');
      }
      episodesCount++;
    }

    final subtitle = _buildSubtitleText(
      l10n,
      totalTitles: totalCount,
      totalMovies: totalMovies,
      totalSeries: totalSeries,
      filteredTitles: filteredTotalTitles,
      filteredMovies: filteredMovies,
      filteredSeries: filteredSeries,
      seasonsCount: seasonsSet.length,
      episodesCount: episodesCount,
    );

    final gridItems = _viewMode == HistoryViewMode.grid
        ? items.take(_visibleGridCount).toList()
        : items;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 800) {
          _loadMoreIfNeeded(items.length);
        }
        return false;
      },
      child: RefreshIndicator(
        color: AppTheme.accent,
        backgroundColor: AppTheme.surface,
        onRefresh: () async {
          final userId = ref.read(userIdProvider);
          if (userId != null) {
            await ref
                .read(watchHistoryRepositoryProvider)
                .syncWatchHistory(userId);
          }
          ref.invalidate(watchLogsProvider);
          await ref.read(watchLogsProvider.future);
        },
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
                child: isDesktop
                    ? _buildDesktopHeader(context, l10n, subtitle)
                    : _buildMobileHeader(context, l10n, subtitle),
              ),
            ),
            if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(l10n),
              )
            else if (_viewMode == HistoryViewMode.grid)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  32,
                ),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.crossAxisExtent;
                    final isMobile = availableWidth < 600;
                    const spacing = 10.0;
                    final crossAxisCount = isMobile
                        ? 3
                        : ((availableWidth + spacing) / (140 + spacing))
                              .floor()
                              .clamp(3, 8);
                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.54,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildGridItem(
                          context,
                          gridItems[index],
                          appLanguage,
                          l10n,
                        ),
                        childCount: gridItems.length,
                      ),
                    );
                  },
                ),
              )
            else
              _buildTimelineSliver(
                context,
                items,
                horizontalPadding,
                appLanguage,
                l10n,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopHeader(
    BuildContext context,
    AppLocalizations l10n,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Back button, Title & Subtitle ... Search bar & View toggle on right
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppBackButton(onTap: () => Navigator.of(context).pop()),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.watchHistoryTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Spacer(),
            _buildSearchBar(l10n, width: 280),
            const SizedBox(width: 12),
            _buildViewModeToggle(l10n),
          ],
        ),
        const SizedBox(height: 20),
        // Row 2: Filter controls (Type pills, Status pills, Granularity toggle & Sort dropdown)
        Row(
          children: [
            _buildTypeFilter(l10n),
            const SizedBox(width: 12),
            _buildStatusFilter(l10n),
            const Spacer(),
            if (_viewMode == HistoryViewMode.timeline) ...[
              _buildGranularityToggle(l10n),
              const SizedBox(width: 10),
            ],
            _buildSortDropdown(l10n),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileHeader(
    BuildContext context,
    AppLocalizations l10n,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppBackButton(
              onTap: () => Navigator.of(context).pop(),
              padding: 10,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.watchHistoryTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSearchBar(l10n),
        const SizedBox(height: 14),
        _buildMobileToolbar(context, l10n),
      ],
    );
  }

  Widget _buildMobileToolbar(BuildContext context, AppLocalizations l10n) {
    final activeCount = _calculateActiveFilterCount();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildViewModeToggle(l10n),
        _buildMobileFilterButton(context, l10n, activeCount),
      ],
    );
  }

  int _calculateActiveFilterCount() {
    int count = 0;
    if (_selectedType != null) count++;
    if (_selectedStatus != null) count++;
    if (_sortOption != HistorySortOption.recentlyWatched) count++;
    if (_viewMode == HistoryViewMode.timeline &&
        _granularity != TimelineGranularity.daily) {
      count++;
    }
    return count;
  }

  Widget _buildMobileFilterButton(
    BuildContext context,
    AppLocalizations l10n,
    int activeCount,
  ) {
    final hasActive = activeCount > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openFilterSheet(context),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: hasActive
                ? AppTheme.accent.withValues(alpha: 0.15)
                : AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasActive
                  ? AppTheme.accent
                  : Colors.white.withValues(alpha: 0.1),
              width: hasActive ? 1.2 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 16,
                color: hasActive ? AppTheme.accent : Colors.white70,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.watchHistoryFiltersTitle,
                style: TextStyle(
                  color: hasActive ? Colors.white : Colors.white70,
                  fontSize: 13,
                  fontWeight: hasActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (hasActive) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    activeCount.toString(),
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFilterSheet(BuildContext context) async {
    final result = await WatchHistoryFilterSheet.show(
      context: context,
      currentType: _selectedType,
      currentStatus: _selectedStatus,
      currentSortOption: _sortOption,
      currentGranularity: _granularity,
      isTimelineMode: _viewMode == HistoryViewMode.timeline,
    );

    if (result != null && mounted) {
      setState(() {
        _selectedType = result.type;
        _selectedStatus = result.status;
        _sortOption = result.sortOption;
        _granularity = result.granularity;
        _resetPagination();
      });
    }
  }

  String _buildSubtitleText(
    AppLocalizations l10n, {
    required int totalTitles,
    required int totalMovies,
    required int totalSeries,
    required int filteredTitles,
    required int filteredMovies,
    required int filteredSeries,
    required int seasonsCount,
    required int episodesCount,
  }) {
    if (totalTitles == 0) {
      return l10n.watchHistorySubtitle(0);
    }

    final hasRefiningFilter =
        _selectedStatus != null || _searchQuery.isNotEmpty;

    // 1. Only movies selected
    if (_selectedType == MediaKind.movie) {
      if (hasRefiningFilter) {
        return l10n.watchHistoryFilteredMoviesCount(
          filteredMovies,
          totalMovies,
        );
      }
      return l10n.watchHistoryMoviesCount(totalMovies);
    }

    // 2. Only series selected
    if (_selectedType == MediaKind.tv) {
      if (hasRefiningFilter) {
        return l10n.watchHistoryFilteredSeriesBreakdown(
          filteredSeries,
          totalSeries,
          seasonsCount,
          episodesCount,
        );
      }
      return l10n.watchHistorySeriesBreakdown(
        totalSeries,
        seasonsCount,
        episodesCount,
      );
    }

    // 3. Both (All) selected
    if (hasRefiningFilter) {
      return l10n.watchHistoryFilteredCount(filteredTitles, totalTitles);
    }
    if (totalMovies > 0 && totalSeries > 0) {
      return '${l10n.watchHistorySubtitle(totalTitles)} • ${l10n.watchHistoryBreakdown(totalMovies, totalSeries)}';
    }
    return l10n.watchHistorySubtitle(totalTitles);
  }

  Widget _buildSearchBar(AppLocalizations l10n, {double? width}) {
    final isFocused = _searchFocusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFocused
              ? AppTheme.accent.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.1),
          width: isFocused ? 1.5 : 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: isFocused ? AppTheme.accent : AppTheme.textMuted,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              cursorColor: AppTheme.accent,
              decoration: InputDecoration(
                hintText: l10n.watchHistorySearchPlaceholder,
                hintStyle: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            DpadFocusable(
              onTap: _searchController.clear,
              showFocusRing: true,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  color: AppTheme.textMuted,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeFilter(AppLocalizations l10n) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPillButton(
            label: l10n.watchHistoryAll,
            icon: Icons.grid_view_rounded,
            isSelected: _selectedType == null,
            onTap: () => setState(() {
              _selectedType = null;
              _resetPagination();
            }),
          ),
          _buildPillButton(
            label: l10n.searchMovies,
            icon: Icons.movie_outlined,
            isSelected: _selectedType == MediaKind.movie,
            onTap: () => setState(() {
              _selectedType = MediaKind.movie;
              _resetPagination();
            }),
          ),
          _buildPillButton(
            label: l10n.searchSeries,
            icon: Icons.tv_outlined,
            isSelected: _selectedType == MediaKind.tv,
            onTap: () => setState(() {
              _selectedType = MediaKind.tv;
              _resetPagination();
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter(AppLocalizations l10n) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPillButton(
            label: l10n.watchHistoryStatusAll,
            isSelected: _selectedStatus == null,
            onTap: () => setState(() {
              _selectedStatus = null;
              _resetPagination();
            }),
          ),
          _buildPillButton(
            label: l10n.watchHistoryStatusWatching,
            icon: Icons.play_circle_outline_rounded,
            isSelected: _selectedStatus == WatchStatus.watching,
            onTap: () => setState(() {
              _selectedStatus = WatchStatus.watching;
              _resetPagination();
            }),
          ),
          _buildPillButton(
            label: l10n.watchHistoryStatusCompleted,
            icon: Icons.check_circle_outline_rounded,
            isSelected: _selectedStatus == WatchStatus.completed,
            onTap: () => setState(() {
              _selectedStatus = WatchStatus.completed;
              _resetPagination();
            }),
          ),
          _buildPillButton(
            label: l10n.watchHistoryStatusDropped,
            icon: Icons.cancel_outlined,
            isSelected: _selectedStatus == WatchStatus.dropped,
            onTap: () => setState(() {
              _selectedStatus = WatchStatus.dropped;
              _resetPagination();
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPillButton({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return DpadFocusable(
      onTap: onTap,
      showFocusRing: true,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.black : AppTheme.textMuted,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : AppTheme.textMuted,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortDropdown(AppLocalizations l10n) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<HistorySortOption>(
          value: _sortOption,
          dropdownColor: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          icon: const Padding(
            padding: EdgeInsets.only(left: 6),
            child: Icon(
              Icons.arrow_drop_down,
              color: AppTheme.textMuted,
              size: 20,
            ),
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _sortOption = val;
                _resetPagination();
              });
            }
          },
          items: [
            DropdownMenuItem(
              value: HistorySortOption.recentlyWatched,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 15,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(l10n.watchHistorySortRecent),
                ],
              ),
            ),
            DropdownMenuItem(
              value: HistorySortOption.releaseDate,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(l10n.searchNewestReleases),
                ],
              ),
            ),
            DropdownMenuItem(
              value: HistorySortOption.rating,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_outline_rounded,
                    size: 15,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(l10n.searchHighestRated),
                ],
              ),
            ),
            DropdownMenuItem(
              value: HistorySortOption.title,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.sort_by_alpha_rounded,
                    size: 15,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(l10n.watchHistorySortTitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridItem(
    BuildContext context,
    WatchHistory item,
    String appLanguage,
    AppLocalizations l10n, {
    int? stackCount,
    String? customInfoText,
  }) {
    final media = item.media;
    final title = media?.getLocalizedTitle(appLanguage) ?? l10n.commonUnknown;
    final posterPath = media?.posterPath;
    final releaseYear = media?.releaseDate?.year.toString();
    final rating = media?.voteAverage;

    // Calculate progress fraction if not completed
    final double? progress =
        (item.totalDuration != null &&
            item.totalDuration! > 0 &&
            item.status != WatchStatus.completed &&
            item.progressSeconds > 0)
        ? (item.progressSeconds / item.totalDuration!)
        : null;

    // Format episode badge (only in Timeline mode, Grid mode remains clean)
    final bool isTimeline = _viewMode == HistoryViewMode.timeline;
    final String? infoText = !isTimeline
        ? null
        : (customInfoText ??
              ((item.mediaType == MediaKind.tv &&
                      item.season != null &&
                      item.episode != null &&
                      item.season! > 0 &&
                      item.episode! > 0)
                  ? 'S${item.season} E${item.episode}'
                  : null));

    return MediaCard(
      title: title,
      posterPath: posterPath,
      releaseDate: releaseYear,
      rating: rating,
      tmdbId: item.tmdbId,
      mediaType: item.mediaType,
      progress: progress,
      infoText: infoText,
      stackCount: isTimeline ? stackCount : null,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MediaDetailsScreen(
              mediaId: item.tmdbId.toString(),
              mediaType: item.mediaType.name,
            ),
          ),
        );
      },
      onPlay: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(
              queryId: item.tmdbId.toString(),
              type: item.mediaType.name,
              season: item.season,
              episode: item.episode,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
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
            l10n.watchHistoryEmpty,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  List<WatchHistory> _filterAndSortItems(
    List<WatchHistory> source,
    String appLanguage,
  ) {
    if (identical(_lastRawList, source) &&
        _lastType == _selectedType &&
        _lastStatus == _selectedStatus &&
        _lastQuery == _searchQuery &&
        _lastViewMode == _viewMode &&
        _lastSortOption == _sortOption &&
        _lastLanguage == appLanguage) {
      return _cachedFilteredList;
    }

    final computed = _computeFilterAndSortItems(source, appLanguage);

    _lastRawList = source;
    _lastType = _selectedType;
    _lastStatus = _selectedStatus;
    _lastQuery = _searchQuery;
    _lastViewMode = _viewMode;
    _lastSortOption = _sortOption;
    _lastLanguage = appLanguage;
    _cachedFilteredList = computed;

    return computed;
  }

  List<WatchHistory> _computeFilterAndSortItems(
    List<WatchHistory> source,
    String appLanguage,
  ) {
    // 1. Filter out entries without media object
    var list = source.where((h) => h.media != null).toList();

    // 2. Filter by media type
    if (_selectedType != null) {
      list = list.where((h) => h.mediaType == _selectedType).toList();
    }

    // 3. Filter by status
    if (_selectedStatus != null) {
      list = list.where((h) => h.status == _selectedStatus).toList();
    }

    // 4. Filter by search query
    if (_searchQuery.isNotEmpty) {
      list = list.where((h) {
        final title = (h.media?.getLocalizedTitle(appLanguage) ?? '')
            .toLowerCase();
        return title.contains(_searchQuery);
      }).toList();
    }

    // 5. In Grid mode, deduplicate by title key so each title appears once with its latest activity.
    // In Timeline mode, retain all entries so they can be grouped and clustered into decks per date window.
    final List<WatchHistory> result;
    if (_viewMode == HistoryViewMode.grid) {
      final uniqueMap = <String, WatchHistory>{};
      for (final item in list) {
        final existing = uniqueMap[item.titleKey];
        if (existing == null ||
            item.lastWatchedAt.isAfter(existing.lastWatchedAt)) {
          uniqueMap[item.titleKey] = item;
        }
      }
      result = uniqueMap.values.toList();
    } else {
      result = List<WatchHistory>.from(list);
    }

    // 6. Sort
    switch (_sortOption) {
      case HistorySortOption.recentlyWatched:
        result.sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));
        break;
      case HistorySortOption.releaseDate:
        result.sort((a, b) {
          final dateA = a.media?.releaseDate ?? DateTime(1970);
          final dateB = b.media?.releaseDate ?? DateTime(1970);
          return dateB.compareTo(dateA);
        });
        break;
      case HistorySortOption.rating:
        result.sort((a, b) {
          final ratingA = a.media?.voteAverage ?? 0.0;
          final ratingB = b.media?.voteAverage ?? 0.0;
          return ratingB.compareTo(ratingA);
        });
        break;
      case HistorySortOption.title:
        result.sort((a, b) {
          final titleA = a.media?.getLocalizedTitle(appLanguage) ?? '';
          final titleB = b.media?.getLocalizedTitle(appLanguage) ?? '';
          return titleA.compareTo(titleB);
        });
        break;
    }

    return result;
  }

  Widget _buildViewModeToggle(AppLocalizations l10n) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPillButton(
            icon: Icons.grid_view_rounded,
            label: l10n.watchHistoryViewGrid,
            isSelected: _viewMode == HistoryViewMode.grid,
            onTap: () => setState(() {
              _viewMode = HistoryViewMode.grid;
              _resetPagination();
            }),
          ),
          _buildPillButton(
            icon: Icons.view_timeline_rounded,
            label: l10n.watchHistoryViewTimeline,
            isSelected: _viewMode == HistoryViewMode.timeline,
            onTap: () => setState(() {
              _viewMode = HistoryViewMode.timeline;
              _resetPagination();
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildGranularityToggle(AppLocalizations l10n) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPillButton(
            label: l10n.watchHistoryGranularityDaily,
            isSelected: _granularity == TimelineGranularity.daily,
            onTap: () => setState(() {
              _granularity = TimelineGranularity.daily;
              _resetPagination();
            }),
          ),
          _buildPillButton(
            label: l10n.watchHistoryGranularityMonthly,
            isSelected: _granularity == TimelineGranularity.monthly,
            onTap: () => setState(() {
              _granularity = TimelineGranularity.monthly;
              _resetPagination();
            }),
          ),
          _buildPillButton(
            label: l10n.watchHistoryGranularityYearly,
            isSelected: _granularity == TimelineGranularity.yearly,
            onTap: () => setState(() {
              _granularity = TimelineGranularity.yearly;
              _resetPagination();
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSliver(
    BuildContext context,
    List<WatchHistory> items,
    double horizontalPadding,
    String appLanguage,
    AppLocalizations l10n,
  ) {
    final sections = _getTimelineSections(items, appLanguage, l10n);
    if (sections.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final crossAxisExtent = constraints.crossAxisExtent;
        final availableWidth = (crossAxisExtent - (horizontalPadding * 2))
            .clamp(100.0, double.infinity);
        final isMobile = availableWidth < 600;
        const spacing = 10.0;
        final crossAxisCount = isMobile
            ? 3
            : ((availableWidth + spacing) / (140 + spacing)).floor().clamp(
                3,
                8,
              );
        final cardWidth =
            (availableWidth - (crossAxisCount - 1) * spacing) / crossAxisCount;
        final cardHeight = cardWidth / 0.54;

        final visibleSections = sections.take(_visibleSectionCount).toList();
        final rows = _buildTimelineRows(visibleSections, crossAxisCount);

        const headerHeight = 52.0;
        final cardRowHeight = cardHeight + 16.0;

        return SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            0,
            horizontalPadding,
            32,
          ),
          sliver: SliverVariedExtentList.builder(
            itemCount: rows.length,
            itemExtentBuilder: (index, _) => rows[index] is _TimelineHeaderItem
                ? headerHeight
                : cardRowHeight,
            itemBuilder: (context, index) {
              final row = rows[index];
              if (row is _TimelineHeaderItem) {
                return SizedBox(
                  height: headerHeight,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildTimelineSectionHeader(
                      row.title,
                      row.totalCount,
                      l10n,
                    ),
                  ),
                );
              } else if (row is _TimelineCardRowItem) {
                return SizedBox(
                  height: cardRowHeight,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < row.decks.length; i++) ...[
                          if (i > 0) const SizedBox(width: spacing),
                          SizedBox(
                            width: cardWidth,
                            height: cardHeight,
                            child: _buildGridItem(
                              context,
                              row.decks[i].item,
                              appLanguage,
                              l10n,
                              stackCount: row.decks[i].stackCount,
                              customInfoText: row.decks[i].customInfoText,
                            ),
                          ),
                        ],
                        if (row.decks.length < crossAxisCount) const Spacer(),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }

  List<_TimelineSection> _getTimelineSections(
    List<WatchHistory> items,
    String appLanguage,
    AppLocalizations l10n,
  ) {
    if (identical(_lastFilteredForTimeline, items) &&
        _lastGranularity == _granularity &&
        _lastLanguageForTimeline == appLanguage) {
      return _cachedTimelineSections;
    }

    final groups = _groupItemsByDate(items, l10n, appLanguage);
    final sections = <_TimelineSection>[];
    for (final group in groups) {
      final clusteredDecks = _clusterDeckItems(group.items, l10n);
      sections.add(_TimelineSection(title: group.title, decks: clusteredDecks));
    }

    _lastFilteredForTimeline = items;
    _lastGranularity = _granularity;
    _lastLanguageForTimeline = appLanguage;
    _cachedTimelineSections = sections;
    return sections;
  }

  List<_TimelineRowItem> _buildTimelineRows(
    List<_TimelineSection> sections,
    int crossAxisCount,
  ) {
    final rows = <_TimelineRowItem>[];
    for (final section in sections) {
      rows.add(_TimelineHeaderItem(section.title, section.decks.length));
      for (int i = 0; i < section.decks.length; i += crossAxisCount) {
        final end = (i + crossAxisCount < section.decks.length)
            ? i + crossAxisCount
            : section.decks.length;
        rows.add(_TimelineCardRowItem(section.decks.sublist(i, end)));
      }
    }
    return rows;
  }

  /// Groups items for the same TV series into a single deck with stackCount and episode range label
  List<_DeckEntry> _clusterDeckItems(
    List<WatchHistory> items,
    AppLocalizations l10n,
  ) {
    final map = <String, List<WatchHistory>>{};
    final order = <String>[];

    for (final item in items) {
      if (!map.containsKey(item.titleKey)) {
        order.add(item.titleKey);
        map[item.titleKey] = [];
      }
      map[item.titleKey]!.add(item);
    }

    final decks = <_DeckEntry>[];
    for (final id in order) {
      final list = map[id]!;
      // Sort to have the latest watched item as the top card
      list.sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));
      final topItem = list.first;

      if (topItem.mediaType == MediaKind.tv && list.length > 1) {
        final label = _buildSeriesDeckLabel(list, l10n);
        decks.add(
          _DeckEntry(
            item: topItem,
            stackCount: list.length,
            customInfoText: label,
          ),
        );
      } else {
        decks.add(_DeckEntry(item: topItem));
      }
    }

    return decks;
  }

  /// Builds a concise episode/season range label, supporting multi-season binge watching
  String? _buildSeriesDeckLabel(
    List<WatchHistory> list,
    AppLocalizations l10n,
  ) {
    final valid = list
        .where(
          (e) =>
              e.season != null &&
              e.season! > 0 &&
              e.episode != null &&
              e.episode! > 0,
        )
        .toList();

    if (valid.isEmpty) return null;

    final seasonMap = <int, Set<int>>{};
    for (final e in valid) {
      seasonMap.putIfAbsent(e.season!, () => <int>{}).add(e.episode!);
    }

    final seasons = seasonMap.keys.toList()..sort();
    if (seasons.length == 1) {
      return _buildSingleSeasonLabel(
        seasons.first,
        seasonMap[seasons.first]!,
        l10n,
      );
    }

    if (seasons.length == 2) {
      return _buildTwoSeasonLabel(
        seasons[0],
        seasonMap[seasons[0]]!,
        seasons[1],
        seasonMap[seasons[1]]!,
        l10n,
      );
    }

    return l10n.watchHistorySeasonRange(seasons.first, seasons.last);
  }

  String _buildSingleSeasonLabel(
    int season,
    Set<int> episodeSet,
    AppLocalizations l10n,
  ) {
    final eps = episodeSet.toList()..sort();
    if (eps.length > 1) {
      return l10n.watchHistoryEpisodeRange(season, eps.first, eps.last);
    }
    return 'S$season E${eps.first}';
  }

  String _buildTwoSeasonLabel(
    int season1,
    Set<int> eps1,
    int season2,
    Set<int> eps2,
    AppLocalizations l10n,
  ) {
    final sorted1 = eps1.toList()..sort();
    final sorted2 = eps2.toList()..sort();
    return l10n.watchHistoryMultiSeasonRange(
      season1,
      sorted1.first,
      season2,
      sorted2.last,
    );
  }

  Widget _buildTimelineSectionHeader(
    String title,
    int visibleCount,
    AppLocalizations l10n,
  ) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.accent,
            boxShadow: AppTheme.shadowNeonSm,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
          ),
          child: Text(
            l10n.watchHistorySubtitle(visibleCount),
            style: const TextStyle(
              color: AppTheme.accent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<_TimelineGroup> _groupItemsByDate(
    List<WatchHistory> items,
    AppLocalizations l10n,
    String appLanguage,
  ) {
    if (items.isEmpty) return const [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sevenDaysAgo = today.subtract(const Duration(days: 7));
    final startOfMonth = DateTime(now.year, now.month, 1);

    final groupedMap = <String, List<WatchHistory>>{};

    for (final item in items) {
      final date = item.lastWatchedAt;
      final itemDate = DateTime(date.year, date.month, date.day);

      String groupTitle;
      switch (_granularity) {
        case TimelineGranularity.daily:
          if (itemDate == today) {
            groupTitle = l10n.watchHistoryDateToday;
          } else if (itemDate == yesterday) {
            groupTitle = l10n.watchHistoryDateYesterday;
          } else if (itemDate.isAfter(sevenDaysAgo)) {
            groupTitle = l10n.watchHistoryDateThisWeek;
          } else if (itemDate.isAfter(startOfMonth) ||
              itemDate == startOfMonth) {
            groupTitle = l10n.watchHistoryDateThisMonth;
          } else {
            groupTitle = DateFormat.yMMMMd(appLanguage).format(date);
          }
          break;

        case TimelineGranularity.monthly:
          groupTitle = DateFormat.yMMMM(appLanguage).format(date);
          break;

        case TimelineGranularity.yearly:
          groupTitle = DateFormat.y(appLanguage).format(date);
          break;
      }

      groupedMap.putIfAbsent(groupTitle, () => []).add(item);
    }

    return groupedMap.entries
        .map((e) => _TimelineGroup(title: e.key, items: e.value))
        .toList();
  }
}

class _DeckEntry {
  final WatchHistory item;
  final int? stackCount;
  final String? customInfoText;

  const _DeckEntry({required this.item, this.stackCount, this.customInfoText});
}

class _TimelineGroup {
  final String title;
  final List<WatchHistory> items;

  const _TimelineGroup({required this.title, required this.items});
}

class _TimelineSection {
  final String title;
  final List<_DeckEntry> decks;

  const _TimelineSection({required this.title, required this.decks});
}

abstract class _TimelineRowItem {}

class _TimelineHeaderItem extends _TimelineRowItem {
  final String title;
  final int totalCount;

  _TimelineHeaderItem(this.title, this.totalCount);
}

class _TimelineCardRowItem extends _TimelineRowItem {
  final List<_DeckEntry> decks;

  _TimelineCardRowItem(this.decks);
}
