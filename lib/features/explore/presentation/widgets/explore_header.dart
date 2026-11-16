import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'package:cinemuse_app/features/explore/application/explore_providers.dart';
import 'package:cinemuse_app/features/explore/domain/explore_type.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_bottom_sheet.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'active_filters_list.dart';
import 'explore_filter_panel.dart';
import 'explore_type_selector.dart';

/// The top of Explore: the type tabs, the Filters button (not for people)
/// and the active filter chips. Narrow: the button goes under the tabs;
/// wide: it sits at the right, the tabs stay centred.
class ExploreHeader extends ConsumerWidget {
  /// Given to the selected tab, so the navbar can move the focus here.
  final FocusNode selectedTypeFocusNode;

  const ExploreHeader({super.key, required this.selectedTypeFocusNode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ref.watch(exploreMediaTypeProvider);
    final filters = ref.watch(exploreFiltersProvider);
    final filtersNotifier = ref.read(exploreFiltersProvider.notifier);

    final selector = ExploreTypeSelector(
      selectedType: type,
      selectedFocusNode: selectedTypeFocusNode,
      onTypeChanged: ref.read(exploreMediaTypeProvider.notifier).select,
    );
    final filterButton = type == ExploreType.person
        ? null
        : const _FilterToggleButton();

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < Breakpoints.medium;
            return SizedBox(
              width: double.infinity,
              child: isNarrow
                  ? Column(
                      children: [
                        selector,
                        if (filterButton != null) ...[
                          const SizedBox(height: 16),
                          filterButton,
                        ],
                      ],
                    )
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        selector,
                        if (filterButton != null)
                          Positioned(right: 0, child: filterButton),
                      ],
                    ),
            );
          },
        ),
        const SizedBox(height: 24),
        ActiveFiltersList(
          filters: filters,
          onChanged: filtersNotifier.set,
          onClear: filtersNotifier.clear,
        ),
      ],
    );
  }
}

/// "Filters": opens the filter panel in a bottom sheet.
class _FilterToggleButton extends StatelessWidget {
  const _FilterToggleButton();

  @override
  Widget build(BuildContext context) {
    return DpadFocusable(
      onTap: () => AppBottomSheet.show(
        context: context,
        child: const AppBottomSheet(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: ExploreFilterPanel(),
            ),
          ),
        ),
      ),
      scale: 1.05,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.secondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.tune_outlined,
              size: 18,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)!.searchFilterAction,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
