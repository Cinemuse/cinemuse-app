import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/explore/application/explore_providers.dart';
import 'package:cinemuse_app/features/explore/domain/explore_filters.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'filter_section_label.dart';

/// "Sort by": most popular, highest rated, newest.
class SortFilterSection extends ConsumerWidget {
  const SortFilterSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final filters = ref.watch(exploreFiltersProvider);
    final type = ref.watch(exploreMediaTypeProvider);
    final options = [
      (l10n.searchMostPopular, ExploreFilters.defaultSortBy),
      (l10n.searchHighestRated, 'vote_average.desc'),
      (l10n.searchNewestReleases, ExploreFilters.newestSortFor(type)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterSectionLabel(l10n.searchSortBy),
        const SizedBox(height: 4),
        for (final (label, value) in options) ...[
          const SizedBox(height: 8),
          _SortOption(
            label: label,
            isSelected: filters.sortBy == value,
            onTap: () => ref
                .read(exploreFiltersProvider.notifier)
                .set(filters.copyWith(sortBy: value)),
          ),
        ],
      ],
    );
  }
}

class _SortOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DpadFocusable(
      onTap: onTap,
      scale: 1.02,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.textWhite
              : AppTheme.textWhite.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppTheme.textWhite
                : AppTheme.textWhite.withValues(alpha: 0.1),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.textWhite.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? AppTheme.primary
                : AppTheme.textWhite.withValues(alpha: 0.6),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
