import 'package:flutter/material.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import '../../../../core/presentation/theme/app_theme.dart';
import '../../../../core/constants/tmdb_constants.dart';
import '../../domain/explore_filters.dart';
import '../../../../shared/widgets/dpad_focusable.dart';

class ActiveFiltersList extends StatelessWidget {
  final ExploreFilters filters;
  final ValueChanged<ExploreFilters> onChanged;
  final VoidCallback onClear;

  const ActiveFiltersList({
    super.key,
    required this.filters,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (!filters.isFiltered) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        // Genres
        ...filters.genres.map((gId) {
          return _FilterChip(
            label: l10n.genreName(gId),
            onDelete: () => onChanged(filters.toggleGenre(gId)),
          );
        }),

        // Languages
        ...filters.languages.map((code) {
          return _FilterChip(
            label: l10n.languageName(code),
            icon: Icons.language,
            onDelete: () => onChanged(filters.removeLanguage(code)),
          );
        }),

        // Year
        if (filters.hasYearFilter)
          _FilterChip(
            label:
                '${filters.year.start.round()} - ${filters.year.end.round()}',
            icon: Icons.calendar_today,
            onDelete: () =>
                onChanged(filters.copyWith(year: ExploreFilters.yearLimits)),
          ),

        // Rating
        if (filters.hasRatingFilter)
          _FilterChip(
            label:
                '${filters.rating.start.round()} - ${filters.rating.end.round()}',
            icon: Icons.whatshot,
            onDelete: () => onChanged(
              filters.copyWith(rating: ExploreFilters.ratingLimits),
            ),
          ),

        // Vote Count
        if (filters.hasVoteCountFilter)
          _FilterChip(
            label:
                '${filters.voteCount.start.round()} - ${filters.voteCount.end >= ExploreFilters.voteCountLimits.end ? l10n.filterMax : filters.voteCount.end.round()}',
            icon: Icons.thumb_up,
            onDelete: () => onChanged(
              filters.copyWith(voteCount: ExploreFilters.defaultVoteCount),
            ),
          ),

        // Runtime
        if (filters.hasRuntimeFilter)
          _FilterChip(
            label:
                '${filters.runtime.start.round()}m - ${filters.runtime.end >= ExploreFilters.runtimeLimits.end ? l10n.filterMax : '${filters.runtime.end.round()}m'}',
            icon: Icons.access_time,
            onDelete: () => onChanged(
              filters.copyWith(runtime: ExploreFilters.runtimeLimits),
            ),
          ),

        // Clear All
        DpadFocusable(
          onTap: onClear,
          scale: 1.05,
          child: _ClearAllButton(l10n: l10n),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onDelete;

  const _FilterChip({required this.label, this.icon, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.secondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.textWhite.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: AppTheme.textMuted),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 6),
          DpadFocusable(
            tooltip: AppLocalizations.of(context)!.commonRemoveFilter,
            onTap: onDelete,
            scale: 1.2,
            child: Icon(
              Icons.close,
              size: 12,
              color: AppTheme.textWhite.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClearAllButton extends StatefulWidget {
  final AppLocalizations l10n;
  const _ClearAllButton({required this.l10n});

  @override
  State<_ClearAllButton> createState() => _ClearAllButtonState();
}

class _ClearAllButtonState extends State<_ClearAllButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _isHovered
              ? Theme.of(context).colorScheme.error.withValues(alpha: 0.2)
              : Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.error.withValues(alpha: _isHovered ? 0.4 : 0.2),
          ),
        ),
        child: Text(
          widget.l10n.searchClearAll,
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
