import 'package:cinemuse_app/features/explore/application/explore_providers.dart';
import 'package:cinemuse_app/features/explore/domain/explore_filters.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'filter_range_slider.dart';

/// The sliders: rating, years, vote count, runtime.
class RangeFiltersSection extends ConsumerWidget {
  const RangeFiltersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final filters = ref.watch(exploreFiltersProvider);
    void update(ExploreFilters next) =>
        ref.read(exploreFiltersProvider.notifier).set(next);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterRangeSlider(
          min: ExploreFilters.ratingLimits.start,
          max: ExploreFilters.ratingLimits.end,
          values: filters.rating,
          onChanged: (v) => update(filters.copyWith(rating: v)),
          label: l10n.searchRating,
          formatValue: (v) => '${v.start.round()} - ${v.end.round()}',
          icon: Icons.whatshot,
        ),
        const SizedBox(height: 32),
        FilterRangeSlider(
          min: ExploreFilters.yearLimits.start,
          max: ExploreFilters.yearLimits.end,
          values: filters.year,
          onChanged: (v) => update(filters.copyWith(year: v)),
          label: l10n.searchYearRange,
          formatValue: (v) => '${v.start.round()} - ${v.end.round()}',
          icon: Icons.calendar_today_outlined,
        ),
        const SizedBox(height: 32),
        FilterRangeSlider(
          min: ExploreFilters.voteCountLimits.start,
          max: ExploreFilters.voteCountLimits.end,
          values: filters.voteCount,
          onChanged: (v) => update(filters.copyWith(voteCount: v)),
          label: l10n.searchVoteCount,
          formatValue: (v) =>
              '${v.start.round()} - ${v.end >= ExploreFilters.voteCountLimits.end ? l10n.filterMax : v.end.round()}',
          icon: Icons.thumb_up_outlined,
        ),
        const SizedBox(height: 32),
        FilterRangeSlider(
          min: ExploreFilters.runtimeLimits.start,
          max: ExploreFilters.runtimeLimits.end,
          values: filters.runtime,
          onChanged: (v) => update(filters.copyWith(runtime: v)),
          label: l10n.searchRuntime,
          formatValue: (v) =>
              '${v.start.round()}m - ${v.end >= ExploreFilters.runtimeLimits.end ? l10n.filterMax : '${v.end.round()}m'}',
          icon: Icons.access_time,
        ),
      ],
    );
  }
}
