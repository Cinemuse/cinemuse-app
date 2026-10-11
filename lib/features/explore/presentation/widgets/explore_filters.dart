import 'package:flutter/material.dart';

class ExploreFilters {
  // Slider limits and defaults: the panel, the chips and [isFiltered] all
  // read these, so they can't disagree.
  static const defaultSortBy = 'popularity.desc';
  static const ratingLimits = RangeValues(0, 10);
  static const voteCountLimits = RangeValues(0, 20000);
  // Hides titles with almost no votes (mostly empty TMDB entries).
  static const defaultVoteCount = RangeValues(100, 20000);
  static const runtimeLimits = RangeValues(0, 240);

  /// Up to next year, so announced titles can be found too.
  static RangeValues get yearLimits =>
      RangeValues(1900, DateTime.now().year + 1.0);

  final String sortBy;
  final List<int> genres;
  final List<String> languages;
  final RangeValues rating;
  final RangeValues year;
  final RangeValues voteCount;
  final RangeValues runtime;
  final List<int> watchProviders;
  final String watchRegion;

  ExploreFilters({
    this.sortBy = defaultSortBy,
    this.genres = const [],
    this.languages = const [],
    this.rating = ratingLimits,
    RangeValues? year,
    this.voteCount = defaultVoteCount,
    this.runtime = runtimeLimits,
    this.watchProviders = const [],
    this.watchRegion = 'IT',
  }) : year = year ?? yearLimits;

  ExploreFilters copyWith({
    String? sortBy,
    List<int>? genres,
    List<String>? languages,
    RangeValues? rating,
    RangeValues? year,
    RangeValues? voteCount,
    RangeValues? runtime,
    List<int>? watchProviders,
    String? watchRegion,
  }) {
    return ExploreFilters(
      sortBy: sortBy ?? this.sortBy,
      genres: genres ?? this.genres,
      languages: languages ?? this.languages,
      rating: rating ?? this.rating,
      year: year ?? this.year,
      voteCount: voteCount ?? this.voteCount,
      runtime: runtime ?? this.runtime,
      watchProviders: watchProviders ?? this.watchProviders,
      watchRegion: watchRegion ?? this.watchRegion,
    );
  }

  bool get hasRatingFilter => rating != ratingLimits;
  bool get hasYearFilter => year != yearLimits;
  bool get hasVoteCountFilter => voteCount != defaultVoteCount;
  bool get hasRuntimeFilter => runtime != runtimeLimits;

  /// True when anything differs from the defaults ("Clear all" is shown).
  bool get isFiltered {
    return sortBy != defaultSortBy ||
        genres.isNotEmpty ||
        languages.isNotEmpty ||
        hasRatingFilter ||
        hasYearFilter ||
        hasVoteCountFilter ||
        hasRuntimeFilter ||
        watchProviders.isNotEmpty;
  }
}
