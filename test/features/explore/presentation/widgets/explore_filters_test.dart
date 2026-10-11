import 'package:cinemuse_app/features/explore/presentation/widgets/explore_filters.dart';
import 'package:cinemuse_app/features/explore/presentation/widgets/media_type_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the default filters count as "not filtered"', () {
    expect(ExploreFilters().isFiltered, isFalse);
  });

  test('the year range reaches next year', () {
    expect(ExploreFilters().year.end, DateTime.now().year + 1);
  });

  test('resetting a slider to its default clears the filter', () {
    final filtered = ExploreFilters().copyWith(
      voteCount: const RangeValues(500, 20000),
    );
    expect(filtered.isFiltered, isTrue);

    final reset = filtered.copyWith(voteCount: ExploreFilters.defaultVoteCount);
    expect(reset.hasVoteCountFilter, isFalse);
    expect(reset.isFiltered, isFalse);
  });

  test('moving the filters to series drops movie-only genres and renames '
      'the "newest" sort', () {
    final movieFilters = ExploreFilters(
      genres: const [28, 35],
      sortBy: ExploreFilters.newestSortFor(MediaType.movie),
    );

    final tvFilters = movieFilters.forType(MediaType.tv);

    expect(tvFilters.genres, [35]);
    expect(tvFilters.sortBy, 'first_air_date.desc');
  });
}
