import 'package:flutter/material.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import '../../../../core/presentation/theme/app_theme.dart';
import '../../../../core/constants/tmdb_constants.dart';
import 'explore_filters.dart';
import '../../../../shared/widgets/hover_scale.dart';

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
          final genre = TmdbConstants.genresList.firstWhere((g) => g['id'] == gId);
          return _FilterChip(
            label: genre['name'] as String,
            onDelete: () {
              final newGenres = List<int>.from(filters.genres)..remove(gId);
              onChanged(filters.copyWith(genres: newGenres));
            },
          );
        }),

        // Languages
        ...filters.languages.map((code) {
          final lang = TmdbConstants.languagesList.firstWhere((l) => l['code'] == code);
          return _FilterChip(
            label: lang['name']!,
            icon: Icons.language,
            onDelete: () {
              final newLangs = List<String>.from(filters.languages)..remove(code);
              onChanged(filters.copyWith(languages: newLangs));
            },
          );
        }),

        // Year
        if (filters.year.start != 1900 || filters.year.end != 2025)
          _FilterChip(
            label: '${filters.year.start.round()} - ${filters.year.end.round()}',
            icon: Icons.calendar_today,
            onDelete: () => onChanged(filters.copyWith(year: const RangeValues(1900, 2025))),
          ),

        // Rating
        if (filters.rating.start != 0 || filters.rating.end != 10)
          _FilterChip(
            label: '${filters.rating.start.round()} - ${filters.rating.end.round()}',
            icon: Icons.whatshot,
            onDelete: () => onChanged(filters.copyWith(rating: const RangeValues(0, 10))),
          ),

        // Vote Count
        if (filters.voteCount.start != 0 || filters.voteCount.end != 20000)
          _FilterChip(
            label: '${filters.voteCount.start.round()} - ${filters.voteCount.end.round() >= 20000 ? l10n.filterMax : filters.voteCount.end.round()}',
            icon: Icons.thumb_up,
            onDelete: () => onChanged(filters.copyWith(voteCount: const RangeValues(0, 20000))),
          ),

        // Runtime
        if (filters.runtime.start != 0 || filters.runtime.end != 240)
          _FilterChip(
            label: '${filters.runtime.start.round()}m - ${filters.runtime.end.round() >= 240 ? l10n.filterMax : filters.runtime.end.round().toString() + 'm'}',
            icon: Icons.access_time,
            onDelete: () => onChanged(filters.copyWith(runtime: const RangeValues(0, 240))),
          ),

        // Clear All
        HoverScale(
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

  const _FilterChip({
    required this.label,
    this.icon,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.secondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.textWhite.withOpacity(0.1)),
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
            style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500, fontSize: 11),
          ),
          const SizedBox(width: 6),
          HoverScale(
            onTap: onDelete,
            scale: 1.2,
            child: Icon(Icons.close, size: 12, color: AppTheme.textWhite.withOpacity(0.4)),
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
          color: _isHovered ? Theme.of(context).colorScheme.error.withOpacity(0.2) : Theme.of(context).colorScheme.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).colorScheme.error.withOpacity(_isHovered ? 0.4 : 0.2)),
        ),
        child: Text(
          widget.l10n.searchClearAll,
          style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold, fontSize: 11),
        ),
      ),
    );
  }
}
