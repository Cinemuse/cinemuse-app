import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/profile/domain/watch_history_filter.dart';
import 'package:cinemuse_app/features/profile/domain/watch_history_view.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/segmented_pills.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/watch_history_filter_options.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/watch_history_search_bar.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_back_button.dart';
import 'package:cinemuse_app/shared/widgets/menu/menu_focus_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// The watch history title, counts, search and filters. Wide windows show
/// every filter; narrow ones a Filters button that opens the sheet.
class WatchHistoryHeader extends StatelessWidget {
  final bool isDesktop;
  final WatchHistoryFilter filter;
  final WatchHistoryCounts counts;

  /// The titles shown in the Ratings view, once they are known.
  final int? ratedCount;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<WatchHistoryFilter> onFilterChanged;
  final VoidCallback onOpenFilterSheet;

  const WatchHistoryHeader({
    super.key,
    required this.isDesktop,
    required this.filter,
    required this.counts,
    this.ratedCount,
    required this.searchController,
    required this.searchFocusNode,
    required this.onFilterChanged,
    required this.onOpenFilterSheet,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final titleRow = Row(
      children: [
        AppBackButton(
          onTap: () => Navigator.of(context).pop(),
          padding: isDesktop ? 12 : 10,
        ),
        SizedBox(width: isDesktop ? 16 : 12),
        Expanded(
          child: _TitleAndCounts(
            isDesktop: isDesktop,
            subtitle: _subtitle(l10n),
          ),
        ),
        if (isDesktop) ...[
          WatchHistorySearchBar(
            controller: searchController,
            focusNode: searchFocusNode,
            width: 280,
          ),
          const SizedBox(width: 12),
          _viewModePills(),
        ],
      ],
    );

    if (!isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleRow,
          const SizedBox(height: 16),
          WatchHistorySearchBar(
            controller: searchController,
            focusNode: searchFocusNode,
          ),
          const SizedBox(height: 14),
          _OneLineOrTwo(
            children: [
              _viewModePills(),
              _FiltersButton(
                activeCount: filter.activeFilterCount,
                onTap: onOpenFilterSheet,
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        titleRow,
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wraps to two lines when the window is narrow (REV-105).
            Expanded(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SegmentedPills(
                    options: typeOptions,
                    selected: filter.type,
                    onSelected: (v) => onFilterChanged(filter.withType(v)),
                  ),
                  SegmentedPills(
                    options: statusOptions,
                    selected: filter.status,
                    onSelected: (v) => onFilterChanged(filter.withStatus(v)),
                  ),
                ],
              ),
            ),
            if (filter.isTimeline) ...[
              SegmentedPills(
                options: granularityOptions,
                selected: filter.granularity,
                onSelected: (v) =>
                    onFilterChanged(filter.copyWith(granularity: v)),
              ),
              const SizedBox(width: 10),
            ],
            _SortDropdown(
              selected: filter.sortOption,
              onSelected: (v) =>
                  onFilterChanged(filter.copyWith(sortOption: v)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _viewModePills() => SegmentedPills(
    options: viewModeOptions,
    selected: filter.viewMode,
    onSelected: (v) => onFilterChanged(filter.copyWith(viewMode: v)),
  );

  String _subtitle(AppLocalizations l10n) {
    final c = counts;
    if (c.totalTitles == 0) return l10n.watchHistorySubtitle(0);
    final rated = ratedCount;
    if (rated != null) {
      return l10n.watchHistoryRatedCount(rated, c.filteredTitles);
    }

    final isRefined = filter.status != null || filter.query.isNotEmpty;
    switch (filter.type) {
      case MediaKind.movie:
        return isRefined
            ? l10n.watchHistoryFilteredMoviesCount(
                c.filteredMovies,
                c.totalMovies,
              )
            : l10n.watchHistoryMoviesCount(c.totalMovies);
      case MediaKind.tv:
        return isRefined
            ? l10n.watchHistoryFilteredSeriesBreakdown(
                c.filteredSeries,
                c.totalSeries,
                c.seasons,
                c.episodes,
              )
            : l10n.watchHistorySeriesBreakdown(
                c.totalSeries,
                c.seasons,
                c.episodes,
              );
      case null || MediaKind.episode:
        if (isRefined) {
          return l10n.watchHistoryFilteredCount(
            c.filteredTitles,
            c.totalTitles,
          );
        }
        if (c.totalMovies > 0 && c.totalSeries > 0) {
          return '${l10n.watchHistorySubtitle(c.totalTitles)} • ${l10n.watchHistoryBreakdown(c.totalMovies, c.totalSeries)}';
        }
        return l10n.watchHistorySubtitle(c.totalTitles);
    }
  }
}

/// Two children on one line, at its two ends. When they don't fit, the second
/// goes on its own line below, still at the right: no widget of Flutter's keeps
/// the first at the left and the second at the right on two lines.
class _OneLineOrTwo extends MultiChildRenderObjectWidget {
  const _OneLineOrTwo({required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderOneLineOrTwo();
}

class _RenderOneLineOrTwo extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, MultiChildLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, MultiChildLayoutParentData> {
  static const _lineGap = 8.0;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! MultiChildLayoutParentData) {
      child.parentData = MultiChildLayoutParentData();
    }
  }

  @override
  void performLayout() {
    final first = firstChild!;
    final second = childAfter(first)!;
    final loose = BoxConstraints(maxWidth: constraints.maxWidth);
    first.layout(loose, parentUsesSize: true);
    second.layout(loose, parentUsesSize: true);
    final width = constraints.maxWidth;
    final fits = first.size.width + second.size.width <= width;
    (first.parentData! as MultiChildLayoutParentData).offset = Offset.zero;
    (second.parentData! as MultiChildLayoutParentData).offset = Offset(
      width - second.size.width,
      fits ? 0 : first.size.height + _lineGap,
    );
    size = constraints.constrain(
      Size(
        width,
        fits
            ? first.size.height
            : first.size.height + _lineGap + second.size.height,
      ),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

class _TitleAndCounts extends StatelessWidget {
  final bool isDesktop;
  final String subtitle;

  const _TitleAndCounts({required this.isDesktop, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.watchHistoryTitle,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: isDesktop ? 26 : 20,
            fontWeight: FontWeight.bold,
            letterSpacing: isDesktop ? -0.5 : null,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: isDesktop ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: isDesktop ? 13 : 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _FiltersButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onTap;

  const _FiltersButton({required this.activeCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasActive = activeCount > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor: AppTheme.clickCursor,
        onTap: onTap,
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
}

class _SortDropdown extends StatelessWidget {
  final HistorySortOption selected;
  final ValueChanged<HistorySortOption> onSelected;

  const _SortDropdown({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
          value: selected,
          dropdownColor: AppTheme.surface,
          mouseCursor: AppTheme.clickCursor,
          dropdownMenuItemMouseCursor: AppTheme.clickCursor,
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
          onChanged: (v) {
            if (v != null) onSelected(v);
          },
          items: withMenuFocusRings([
            for (final option in sortOptions)
              DropdownMenuItem(
                value: option.value,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(option.icon, size: 15, color: AppTheme.textMuted),
                    const SizedBox(width: 6),
                    Text(option.label(l10n)),
                  ],
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
