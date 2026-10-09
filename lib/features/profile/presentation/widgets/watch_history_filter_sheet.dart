import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/profile/presentation/watch_history_screen.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_bottom_sheet.dart';

class WatchHistoryFilterResult {
  final MediaKind? type;
  final WatchStatus? status;
  final HistorySortOption sortOption;
  final TimelineGranularity granularity;

  const WatchHistoryFilterResult({
    required this.type,
    required this.status,
    required this.sortOption,
    required this.granularity,
  });
}

class WatchHistoryFilterSheet extends StatefulWidget {
  final MediaKind? initialType;
  final WatchStatus? initialStatus;
  final HistorySortOption initialSortOption;
  final TimelineGranularity initialGranularity;
  final bool isTimelineMode;

  const WatchHistoryFilterSheet({
    super.key,
    required this.initialType,
    required this.initialStatus,
    required this.initialSortOption,
    required this.initialGranularity,
    required this.isTimelineMode,
  });

  static Future<WatchHistoryFilterResult?> show({
    required BuildContext context,
    required MediaKind? currentType,
    required WatchStatus? currentStatus,
    required HistorySortOption currentSortOption,
    required TimelineGranularity currentGranularity,
    required bool isTimelineMode,
  }) {
    return AppBottomSheet.show<WatchHistoryFilterResult>(
      context: context,
      child: WatchHistoryFilterSheet(
        initialType: currentType,
        initialStatus: currentStatus,
        initialSortOption: currentSortOption,
        initialGranularity: currentGranularity,
        isTimelineMode: isTimelineMode,
      ),
    );
  }

  @override
  State<WatchHistoryFilterSheet> createState() =>
      _WatchHistoryFilterSheetState();
}

class _WatchHistoryFilterSheetState extends State<WatchHistoryFilterSheet> {
  late MediaKind? _selectedType;
  late WatchStatus? _selectedStatus;
  late HistorySortOption _selectedSortOption;
  late TimelineGranularity _selectedGranularity;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _selectedStatus = widget.initialStatus;
    _selectedSortOption = widget.initialSortOption;
    _selectedGranularity = widget.initialGranularity;
  }

  bool get _hasActiveFilters {
    return _selectedType != null ||
        _selectedStatus != null ||
        _selectedSortOption != HistorySortOption.recentlyWatched ||
        (widget.isTimelineMode &&
            _selectedGranularity != TimelineGranularity.daily);
  }

  void _resetFilters() {
    setState(() {
      _selectedType = null;
      _selectedStatus = null;
      _selectedSortOption = HistorySortOption.recentlyWatched;
      _selectedGranularity = TimelineGranularity.daily;
    });
  }

  void _applyFilters() {
    Navigator.of(context).pop(
      WatchHistoryFilterResult(
        type: _selectedType,
        status: _selectedStatus,
        sortOption: _selectedSortOption,
        granularity: _selectedGranularity,
      ),
    );
  }

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
              _buildTypeChips(l10n),
              const SizedBox(height: 20),
              _buildSectionTitle(l10n.watchHistoryFilterStatus),
              const SizedBox(height: 10),
              _buildStatusChips(l10n),
              const SizedBox(height: 20),
              _buildSectionTitle(l10n.watchHistoryFilterSort),
              const SizedBox(height: 10),
              _buildSortChips(l10n),
              if (widget.isTimelineMode) ...[
                const SizedBox(height: 20),
                _buildSectionTitle(l10n.watchHistoryFilterGranularity),
                const SizedBox(height: 10),
                _buildGranularityChips(l10n),
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
        if (_hasActiveFilters)
          TextButton(
            onPressed: _resetFilters,
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

  Widget _buildTypeChips(AppLocalizations l10n) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildSelectableChip(
          label: l10n.watchHistoryAll,
          isSelected: _selectedType == null,
          onTap: () => setState(() => _selectedType = null),
        ),
        _buildSelectableChip(
          label: l10n.searchMovies,
          isSelected: _selectedType == MediaKind.movie,
          onTap: () => setState(() => _selectedType = MediaKind.movie),
        ),
        _buildSelectableChip(
          label: l10n.searchSeries,
          isSelected: _selectedType == MediaKind.tv,
          onTap: () => setState(() => _selectedType = MediaKind.tv),
        ),
      ],
    );
  }

  Widget _buildStatusChips(AppLocalizations l10n) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildSelectableChip(
          label: l10n.watchHistoryStatusAll,
          isSelected: _selectedStatus == null,
          onTap: () => setState(() => _selectedStatus = null),
        ),
        _buildSelectableChip(
          label: l10n.watchHistoryStatusWatching,
          isSelected: _selectedStatus == WatchStatus.watching,
          onTap: () => setState(() => _selectedStatus = WatchStatus.watching),
        ),
        _buildSelectableChip(
          label: l10n.watchHistoryStatusCompleted,
          isSelected: _selectedStatus == WatchStatus.completed,
          onTap: () => setState(() => _selectedStatus = WatchStatus.completed),
        ),
        _buildSelectableChip(
          label: l10n.watchHistoryStatusDropped,
          isSelected: _selectedStatus == WatchStatus.dropped,
          onTap: () => setState(() => _selectedStatus = WatchStatus.dropped),
        ),
      ],
    );
  }

  Widget _buildSortChips(AppLocalizations l10n) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildSelectableChip(
          label: l10n.watchHistorySortRecent,
          isSelected: _selectedSortOption == HistorySortOption.recentlyWatched,
          onTap: () => setState(
            () => _selectedSortOption = HistorySortOption.recentlyWatched,
          ),
        ),
        _buildSelectableChip(
          label: l10n.searchNewestReleases,
          isSelected: _selectedSortOption == HistorySortOption.releaseDate,
          onTap: () => setState(
            () => _selectedSortOption = HistorySortOption.releaseDate,
          ),
        ),
        _buildSelectableChip(
          label: l10n.searchHighestRated,
          isSelected: _selectedSortOption == HistorySortOption.rating,
          onTap: () =>
              setState(() => _selectedSortOption = HistorySortOption.rating),
        ),
        _buildSelectableChip(
          label: l10n.watchHistorySortTitle,
          isSelected: _selectedSortOption == HistorySortOption.title,
          onTap: () =>
              setState(() => _selectedSortOption = HistorySortOption.title),
        ),
      ],
    );
  }

  Widget _buildGranularityChips(AppLocalizations l10n) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildSelectableChip(
          label: l10n.watchHistoryGranularityDaily,
          isSelected: _selectedGranularity == TimelineGranularity.daily,
          onTap: () =>
              setState(() => _selectedGranularity = TimelineGranularity.daily),
        ),
        _buildSelectableChip(
          label: l10n.watchHistoryGranularityMonthly,
          isSelected: _selectedGranularity == TimelineGranularity.monthly,
          onTap: () => setState(
            () => _selectedGranularity = TimelineGranularity.monthly,
          ),
        ),
        _buildSelectableChip(
          label: l10n.watchHistoryGranularityYearly,
          isSelected: _selectedGranularity == TimelineGranularity.yearly,
          onTap: () =>
              setState(() => _selectedGranularity = TimelineGranularity.yearly),
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
        onPressed: _applyFilters,
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
