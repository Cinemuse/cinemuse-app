import 'package:cinemuse_app/features/explore/presentation/widgets/explore_filters.dart';
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
}
