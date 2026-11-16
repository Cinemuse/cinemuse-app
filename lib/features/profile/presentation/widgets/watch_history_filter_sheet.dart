import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/profile/domain/watch_history_filter.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/watch_history_filter_options.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_bottom_sheet.dart';

/// The phone's filters: type, status, order and, in the timeline, the
/// granularity. Returns the new filter, or null when dismissed.
class WatchHistoryFilterSheet extends StatefulWidget {
  final WatchHistoryFilter initial;

  const WatchHistoryFilterSheet({super.key, required this.initial});

  static Future<WatchHistoryFilter?> show({
    required BuildContext context,
    required WatchHistoryFilter current,
  }) {
    return AppBottomSheet.show<WatchHistoryFilter>(
      context: context,
      child: WatchHistoryFilterSheet(initial: current),
    );
  }

  @override
  State<WatchHistoryFilterSheet> createState() =>
      _WatchHistoryFilterSheetState();
}

class _WatchHistoryFilterSheetState extends State<WatchHistoryFilterSheet> {
  late WatchHistoryFilter _filter = widget.initial;

  void _set(WatchHistoryFilter filter) => setState(() => _filter = filter);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AppBottomSheet(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(l10n),
              const SizedBox(height: 20),
              _buildSectionTitle(l10n.watchHistoryFilterType),
              const SizedBox(height: 10),
              _buildChips(typeOptions, _filter.type, _filter.withType, l10n),
              const SizedBox(height: 20),
              _buildSectionTitle(l10n.watchHistoryFilterStatus),
              const SizedBox(height: 10),
              _buildChips(
                statusOptions,
                _filter.status,
                _filter.withStatus,
                l10n,
              ),
              const SizedBox(height: 20),
              _buildSectionTitle(l10n.watchHistoryFilterSort),
              const SizedBox(height: 10),
              _buildChips(
                sortOptions,
                _filter.sortOption,
                (v) => _filter.copyWith(sortOption: v),
                l10n,
              ),
              if (_filter.isTimeline) ...[
                const SizedBox(height: 20),
                _buildSectionTitle(l10n.watchHistoryFilterGranularity),
                const SizedBox(height: 10),
                _buildChips(
                  granularityOptions,
                  _filter.granularity,
                  (v) => _filter.copyWith(granularity: v),
                  l10n,
                ),
              ],
              const SizedBox(height: 28),
              _buildApplyButton(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.tune_rounded, color: AppTheme.accent, size: 20),
            const SizedBox(width: 8),
            Text(
              l10n.watchHistoryFiltersTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (_filter.activeFilterCount > 0)
          TextButton(
            onPressed: () => _set(_filter.cleared()),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              l10n.watchHistoryResetFilters,
              style: const TextStyle(
                color: AppTheme.accent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildChips<T>(
    List<FilterOption<T>> options,
    T selected,
    WatchHistoryFilter Function(T value) select,
    AppLocalizations l10n,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          _buildSelectableChip(
            label: option.label(l10n),
            isSelected: option.value == selected,
            onTap: () => _set(select(option.value)),
          ),
      ],
    );
  }

  Widget _buildSelectableChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor: AppTheme.clickCursor,
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accent.withValues(alpha: 0.18)
                : AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppTheme.accent
                  : Colors.white.withValues(alpha: 0.08),
              width: isSelected ? 1.2 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApplyButton(AppLocalizations l10n) {
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).pop(_filter),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accent,
          foregroundColor: AppTheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          l10n.watchHistoryApplyFilters,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
