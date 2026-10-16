import 'package:cinemuse_app/features/explore/domain/explore_filters.dart';
import 'package:cinemuse_app/features/explore/domain/explore_type.dart';
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
      sortBy: ExploreFilters.newestSortFor(ExploreType.movie),
    );

    final tvFilters = movieFilters.forType(ExploreType.tv);

    expect(tvFilters.genres, [35]);
    expect(tvFilters.sortBy, 'first_air_date.desc');
  });

  test('picking a genre or service twice removes it; a language is added '
      'once', () {
    final picked = ExploreFilters()
        .toggleGenre(28)
        .toggleGenre(35)
        .toggleWatchProvider(8)
        .addLanguage('it')
        .addLanguage('it');

    expect(picked.genres, [28, 35]);
    expect(picked.watchProviders, [8]);
    expect(picked.languages, ['it']);

    final removed = picked
        .toggleGenre(28)
        .toggleWatchProvider(8)
        .removeLanguage('it');

    expect(removed.genres, [35]);
    expect(removed.watchProviders, isEmpty);
    expect(removed.languages, isEmpty);
  });
}
